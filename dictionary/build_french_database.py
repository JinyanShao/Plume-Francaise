#!/usr/bin/env python3
"""Build the compact French candidate and context database."""

import json
import sqlite3
import sys
import unicodedata
from pathlib import Path


def normalize(text: str) -> str:
    text = text.lower().replace("’", "'")
    return "".join(
        character
        for character in unicodedata.normalize("NFD", text)
        if unicodedata.category(character) != "Mn"
    )


# Small, deliberately curated seed corpus. Longer contexts take priority at
# runtime and single-word contexts provide a useful fallback.
NGRAMS = {
    "je": ["suis", "vais", "veux", "peux", "pense", "crois", "dois", "me"],
    "je suis": ["heureux", "désolé", "prêt", "ici", "sûr", "en", "très", "un"],
    "tu": ["es", "as", "peux", "veux", "vas", "dois", "me"],
    "il": ["est", "a", "faut", "peut", "va", "y"],
    "elle": ["est", "a", "peut", "va", "nous"],
    "nous": ["sommes", "avons", "pouvons", "allons", "devons"],
    "vous": ["êtes", "avez", "pouvez", "allez", "devez"],
    "ils": ["sont", "ont", "peuvent", "vont", "doivent"],
    "elles": ["sont", "ont", "peuvent", "vont", "doivent"],
    "c'est": ["un", "une", "très", "bien", "vrai", "important", "possible"],
    "il est": ["possible", "important", "temps", "nécessaire", "difficile"],
    "il faut": ["être", "faire", "avoir", "savoir", "prendre"],
    "j'ai": ["besoin", "envie", "déjà", "été", "fait", "vu"],
    "j'aime": ["bien", "beaucoup", "les", "la", "le", "cette"],
    "merci": ["beaucoup", "pour", "de", "à"],
    "de": ["la", "le", "l'", "les", "plus", "faire"],
    "à": ["la", "l'", "un", "une", "faire", "partir"],
    "pour": ["le", "la", "les", "un", "une", "faire"],
    "dans": ["le", "la", "les", "un", "une"],
    "sur": ["le", "la", "les", "un", "une"],
    "avec": ["le", "la", "les", "un", "une"],
}


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit(
            "usage: build_french_database.py french_words_data.json "
            "french_normalized_to_accented.json output.sqlite3"
        )

    words_path, accents_path, output_path = map(Path, sys.argv[1:])
    words_data = json.loads(words_path.read_text())
    accent_map = json.loads(accents_path.read_text())

    output_path.unlink(missing_ok=True)
    database = sqlite3.connect(output_path)
    database.executescript(
        """
        PRAGMA journal_mode = OFF;
        PRAGMA synchronous = OFF;
        CREATE TABLE french_words (
            normalized TEXT NOT NULL,
            word TEXT NOT NULL,
            frequency INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (normalized, word)
        );
        CREATE INDEX idx_french_words_normalized
            ON french_words(normalized, frequency DESC);
        CREATE TABLE french_ngrams (
            context TEXT NOT NULL,
            next_word TEXT NOT NULL,
            frequency INTEGER NOT NULL,
            PRIMARY KEY (context, next_word)
        );
        CREATE INDEX idx_french_ngrams_context
            ON french_ngrams(context, frequency DESC);
        """
    )

    rows = []
    for normalized, variants in accent_map.items():
        for word in variants:
            details = words_data.get(word, {})
            rows.append((normalize(normalized), word, int(details.get("frequency", 0))))
    database.executemany(
        "INSERT OR REPLACE INTO french_words(normalized, word, frequency) VALUES (?, ?, ?)",
        rows,
    )

    ngram_rows = []
    for context, predictions in NGRAMS.items():
        for rank, word in enumerate(predictions):
            ngram_rows.append((normalize(context), word, len(predictions) - rank))
    database.executemany(
        "INSERT INTO french_ngrams(context, next_word, frequency) VALUES (?, ?, ?)",
        ngram_rows,
    )
    database.commit()
    database.execute("VACUUM")
    database.close()


if __name__ == "__main__":
    main()
