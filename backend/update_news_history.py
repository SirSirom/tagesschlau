import json
from datetime import datetime
from pathlib import Path

from build_news_keywords import generate_news_keywords


HISTORY_FILE = "news_history.json"


def load_history(history_file):
    history_path = Path(history_file)
    if not history_path.exists():
        return {}

    with history_path.open("r", encoding="utf-8") as file:
        return json.load(file)


def save_history(history, history_file):
    with open(history_file, "w", encoding="utf-8") as outfile:
        json.dump(history, outfile, indent=4, ensure_ascii=False)


def update_news_history(history_file=HISTORY_FILE):
    history = load_history(history_file)
    today_key = datetime.now().strftime("%Y-%m-%d")
    current_news = generate_news_keywords()

    history[today_key] = current_news
    save_history(history, history_file)

    print(f"History successfully saved to: {history_file}")
    return history_file


if __name__ == "__main__":
    update_news_history()
