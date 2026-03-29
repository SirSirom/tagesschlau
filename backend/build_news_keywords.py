import csv
import html
import json
import re
import spacy
from collections import Counter
from datetime import datetime
from pathlib import Path
from urllib.request import urlopen, Request

# Load spaCy for German noun extraction
nlp = spacy.load("de_core_news_sm")

IDF_FILE = "idf_map.csv"
MAX_IDF = 23.220203666547988
NEWS_API_URL = "https://www.tagesschau.de/api2u/homepage"
NEWS_LIMIT = 4
KEYWORD_LIMIT = 4

def normalize_german(word):
    # Standardize German characters for IDF mapping
    word = word.lower()
    word = word.replace("\u00e4", "ae").replace("\u00f6", "oe").replace("\u00fc", "ue").replace("\u00df", "ss")
    word = word.replace("Ã¤", "ae").replace("Ã¶", "oe").replace("Ã¼", "ue").replace("ÃŸ", "ss")
    return word

def strip_html_tags(text):
    if not text:
        return ""
    text = html.unescape(text)
    text = re.sub(r"<[^>]+>", "", text)
    return re.sub(r"\s+", " ", text).strip()

def load_idf_map(idf_file):
    idf_path = Path(idf_file)
    if not idf_path.exists():
        return {}

    with idf_path.open("r", encoding="utf-8", newline="") as file:
        reader = csv.DictReader(file)
        return {
            row["word"]: float(row["idf"])
            for row in reader
            if row.get("word") and row.get("idf")
        }

def load_news_data(api_url):
    # Use Request with User-Agent to prevent 308 or 403 errors on Linux
    req = Request(api_url, headers={'User-Agent': 'Mozilla/5.0'})
    with urlopen(req) as response:
        return json.load(response)

def parse_date(date_string):
    return datetime.fromisoformat(date_string)

def has_liveblog_tag(item):
    for tag_entry in item.get("tags", []):
        if str(tag_entry.get("tag", "")).strip().lower() == "liveblog":
            return True
    return False

def extract_content(item):
    full_text_parts = []
    for element in item.get("content", []):
        if element.get("type") in ["text", "headline"]:
            value = strip_html_tags(element.get("value", ""))
            if value:
                full_text_parts.append(value)
    return "\n".join(full_text_parts)

def extract_image_url(item):
    # Prefer 16x9 high-res image
    return (
        item.get("teaserImage", {})
        .get("imageVariants", {})
        .get("16x9-1920")
    )

def get_ranked_keywords(text, idf_map):
    if not text:
        return []

    # 1. NLP Filtering: Extract only Nouns and Proper Nouns
    # Connections requires clean, capitalized nouns.
    doc = nlp(text)
    tokens = [
        token.text for token in doc 
        if token.pos_ in ["NOUN", "PROPN"] 
        and not token.is_stop 
        and token.text[0].isupper() # Ensure it's a capitalized German noun
        and len(token.text) > 3
    ]

    if not tokens:
        return []

    # 2. Ranking via TF-IDF on filtered nouns
    term_counts = Counter(tokens)
    total_terms = len(tokens)
    scores = {}

    for word, count in term_counts.items():
        tf = count / total_terms
        word_normalized = normalize_german(word)
        idf = idf_map.get(word_normalized, MAX_IDF)
        scores[word] = tf * idf

    # Sort by score descending
    sorted_scores = sorted(scores.items(), key=lambda item: item[1], reverse=True)
    return [word for word, _ in sorted_scores]

def select_unique_keywords(ranked_keywords, used_keywords, keyword_limit=KEYWORD_LIMIT):
    selected_keywords = []

    for keyword in ranked_keywords:
        normalized_keyword = normalize_german(keyword)
        if normalized_keyword in used_keywords:
            continue

        selected_keywords.append(keyword)
        used_keywords.add(normalized_keyword)

        if len(selected_keywords) == keyword_limit:
            break

    return selected_keywords

def generate_news_keywords(api_url=NEWS_API_URL):
    idf_map = load_idf_map(IDF_FILE)
    data = load_news_data(api_url)

    filtered_news = []
    for item in data.get("news", []):
        if has_liveblog_tag(item):
            continue

        date_value = item.get("date")
        if not date_value:
            continue

        filtered_news.append({
            "title": item.get("title"),
            "date": date_value,
            "shareURL": item.get("shareURL"),
            "imageURL": extract_image_url(item),
            "content": extract_content(item),
        })

    # Get the 4 latest articles
    latest_news = sorted(filtered_news, key=lambda item: parse_date(item["date"]), reverse=True)[:NEWS_LIMIT]

    result = []
    used_keywords = set()

    for item in latest_news:
        ranked_keywords = get_ranked_keywords(item["content"], idf_map)
        result.append({
            "title": item["title"],
            "date": item["date"],
            "shareURL": item["shareURL"],
            "imageURL": item["imageURL"],
            "keywords": select_unique_keywords(ranked_keywords, used_keywords),
        })

    return result

def save_news_keywords(result):
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    output_filename = f"news_keywords_{timestamp}.json"

    with open(output_filename, "w", encoding="utf-8") as outfile:
        json.dump(result, outfile, indent=4, ensure_ascii=False)

    return output_filename

def build_news_keywords(api_url=NEWS_API_URL):
    result = generate_news_keywords(api_url)
    return save_news_keywords(result)

if __name__ == "__main__":
    build_news_keywords()