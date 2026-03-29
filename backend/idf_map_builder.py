import pandas as pd
import numpy as np
import sys

INPUT_FILE = sys.argv[1]
OUTPUT_FILE = sys.argv[2]

df = pd.read_csv(INPUT_FILE, encoding="utf-8-sig")

if not {"word", "freq"}.issubset(df.columns):
    raise ValueError("CSV must contain 'word' and 'freq' columns")

# strip BOM and whitespace
df["word"] = df["word"].str.strip()
df = df[df["word"].notna() & (df["word"] != "")]

# compute total token count
N = df["freq"].sum()

# compute IDF
df["idf"] = np.log(N / df["freq"]).round(6)

# keep only word + idf
df = df[["word", "idf"]]

# save CSV
df.to_csv(OUTPUT_FILE, index=False)

print(f"Processed {len(df)} words.")
print(f"Saved to {OUTPUT_FILE}")