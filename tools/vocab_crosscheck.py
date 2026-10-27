"""Check Signara's draft vocab against an ASL-LEX export.

Download the ASL-LEX data yourself (CC BY-NC 4.0, non-commercial, give credit):
    https://www.sign-lang.uni-hamburg.de/lr/compendium/lex/asllex.html
Save the spreadsheet as CSV (UTF-8), then:

    python tools/vocab_crosscheck.py --lex signdata.csv

Prints which of our glosses have an ASL-LEX entry and which do not.
"Not found" does NOT mean the sign is wrong. It may be spelled differently or
absent from ASL-LEX. It is a to-do list for a human (ideally a Deaf signer).
Matching is by gloss text only. It cannot tell you if a sign is correct.
"""

import argparse
import csv
import json
import os
import re
import sys

ID_COLUMNS = ["EntryID", "Entry ID", "entry_id", "LemmaID", "Lemma ID", "Code", "Gloss", "gloss"]


def norm(s):
    s = s.strip().lower()
    s = re.sub(r"_?\d+$", "", s)  # ACCEPT_1 -> accept
    s = re.sub(r"[-_\s]+", " ", s)
    return s.strip()


def load_lex_glosses(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    if not rows:
        raise SystemExit("CSV is empty.")
    cols = rows[0].keys()
    col = next((c for c in ID_COLUMNS if c in cols), None)
    if col is None:
        raise SystemExit(f"No gloss column found. Columns are: {list(cols)}. "
                         f"Pass --column NAME.")
    return rows, col


def check(vocab_glosses, lex_values):
    lex = {norm(v) for v in lex_values if v}
    found, missing = [], []
    for g in vocab_glosses:
        (found if norm(g) in lex else missing).append(g)
    return found, missing


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lex", required=True)
    ap.add_argument("--vocab", default=os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "assets", "vocab", "vocab_v0.json"))
    ap.add_argument("--column", help="gloss column name in the CSV")
    args = ap.parse_args()

    with open(args.vocab, encoding="utf-8") as f:
        vocab = json.load(f)
    glosses = [s["gloss"] for s in vocab["signs"]]

    rows, col = load_lex_glosses(args.lex)
    if args.column:
        col = args.column
    found, missing = check(glosses, [r.get(col, "") for r in rows])

    print(f"Gloss column: {col}   ASL-LEX rows: {len(rows)}")
    print(f"Found {len(found)}/{len(glosses)}")
    if missing:
        print("\nNot found (check spelling, or confirm with a Deaf signer):")
        for g in missing:
            print("  -", g)
    sys.exit(0)


if __name__ == "__main__":
    main()
