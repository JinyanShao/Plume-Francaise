#!/usr/bin/env python3
"""Import high-frequency French verb conjugations from Morphalou 3.1."""

import argparse
import csv
import sqlite3
import unicodedata
from collections import defaultdict
from pathlib import Path


SUBJECTS = (
    ("je", "singular", "firstPerson"),
    ("tu", "singular", "secondPerson"),
    ("il", "singular", "thirdPerson"),
    ("elle", "singular", "thirdPerson"),
    ("on", "singular", "thirdPerson"),
    ("nous", "plural", "firstPerson"),
    ("vous", "plural", "secondPerson"),
    ("ils", "plural", "thirdPerson"),
    ("elles", "plural", "thirdPerson"),
)

TENSES = (
    ("present", "present"),
    ("imperfect", "imperfect"),
    ("future", "future"),
)

AVOIR_PRESENT = {
    "je": "ai",
    "tu": "as",
    "il": "a",
    "elle": "a",
    "on": "a",
    "nous": "avons",
    "vous": "avez",
    "ils": "ont",
    "elles": "ont",
}

ETRE_PRESENT = {
    "je": "suis",
    "tu": "es",
    "il": "est",
    "elle": "est",
    "on": "est",
    "nous": "sommes",
    "vous": "êtes",
    "ils": "sont",
    "elles": "sont",
}

ETRE_AUXILIARY_LEMMAS = {
    "aller",
    "arriver",
    "descendre",
    "devenir",
    "entrer",
    "intervenir",
    "mourir",
    "monter",
    "naître",
    "partir",
    "parvenir",
    "passer",
    "rentrer",
    "rester",
    "retourner",
    "revenir",
    "sortir",
    "survenir",
    "tomber",
    "venir",
}

DUAL_AUXILIARY_LEMMAS = {
    "descendre",
    "monter",
    "passer",
    "rentrer",
    "retourner",
    "sortir",
}

REQUIRED_LEMMAS = {"être", "pouvoir", "prendre", "mettre", "falloir"}

IMPERSONAL_LEMMAS = {"falloir"}

FORM_PREFERENCES = {
    ("être", "present", "plural", "thirdPerson"): "sont",
    ("pouvoir", "present", "singular", "firstPerson"): "peux",
}


def normalize(text: str) -> str:
    text = text.lower().replace("’", "'")
    return "".join(
        character
        for character in unicodedata.normalize("NFD", text)
        if unicodedata.category(character) != "Mn"
    )


def read_morphalou(path: Path) -> dict:
    entries = defaultdict(lambda: {"forms": defaultdict(set), "participles": defaultdict(set)})
    current_lemma = ""
    with path.open(encoding="utf-8-sig", newline="") as source:
        for line_number, row in enumerate(csv.reader(source, delimiter=";"), start=1):
            if line_number <= 16 or len(row) < 18:
                continue
            if row[0]:
                current_lemma = row[0].strip()
            if not current_lemma:
                continue

            form = row[9].strip()
            number = row[11].strip()
            mood = row[12].strip()
            gender = row[13].strip()
            tense = row[14].strip()
            person = row[15].strip()
            if not form:
                continue

            if mood == "indicative" and tense in {item[1] for item in TENSES}:
                entries[current_lemma]["forms"][(tense, number, person)].add(form)
            elif mood == "participle" and tense == "past":
                entries[current_lemma]["participles"][(number, gender)].add(form)
    return entries


def select_form(values: set) -> str | None:
    if not values:
        return None
    return sorted(values, key=lambda value: (len(value), value))[0]


def candidate_frequency(database: sqlite3.Connection, lemma: str) -> int:
    normalized = normalize(lemma)
    row = database.execute(
        "SELECT MAX(frequency) FROM french_words WHERE normalized = ?",
        (normalized,),
    ).fetchone()
    return int(row[0] or 0)


def exact_candidate_frequency(database: sqlite3.Connection, lemma: str) -> int:
    row = database.execute(
        "SELECT MAX(frequency) FROM french_words WHERE word = ?",
        (lemma,),
    ).fetchone()
    return int(row[0] or 0)


def base_participle(entry: dict) -> str | None:
    for key in (
        ("singular", "masculine"),
        ("invariable", "masculine"),
        ("invariable", "invariable"),
    ):
        form = select_form(entry["participles"].get(key))
        if form:
            return form
    return None


def subjects_for_lemma(lemma: str) -> tuple:
    if lemma in IMPERSONAL_LEMMAS:
        return (("il", "singular", "thirdPerson"),)
    return SUBJECTS


def has_complete_simple_tenses(lemma: str, entry: dict) -> bool:
    required = {
        (tense, number, person)
        for _, tense in TENSES
        for _, number, person in subjects_for_lemma(lemma)
    }
    if lemma in REQUIRED_LEMMAS:
        participle = base_participle(entry)
    else:
        participle = select_form(entry["participles"].get(("singular", "masculine")))
    return required.issubset(entry["forms"]) and bool(participle)


def conjugated_form(lemma: str, entry: dict, tense: str, number: str, person: str) -> str:
    preferred = FORM_PREFERENCES.get((lemma, tense, number, person))
    if preferred:
        return preferred
    return select_form(entry["forms"][(tense, number, person)])


def participle_for_subject(entry: dict, subject: str, uses_etre: bool) -> str:
    if not uses_etre:
        return base_participle(entry)

    if subject in {"elle"}:
        key = ("singular", "feminine")
    elif subject in {"nous", "vous", "ils"}:
        key = ("plural", "masculine")
    elif subject == "elles":
        key = ("plural", "feminine")
    else:
        key = ("singular", "masculine")
    return select_form(entry["participles"].get(key)) or base_participle(entry)


def create_rows(lemma: str, entry: dict, frequency: int) -> list:
    rows = []
    for tense_rank, (stored_tense, source_tense) in enumerate(TENSES):
        for subject_rank, (subject, number, person) in enumerate(subjects_for_lemma(lemma)):
            form = conjugated_form(lemma, entry, source_tense, number, person)
            rows.append(
                (
                    lemma,
                    normalize(lemma),
                    form,
                    normalize(form),
                    stored_tense,
                    subject,
                    tense_rank * 100 + subject_rank,
                    frequency,
                )
            )

    uses_etre = lemma in ETRE_AUXILIARY_LEMMAS
    auxiliary_variants = [(ETRE_PRESENT if uses_etre else AVOIR_PRESENT, uses_etre, 0)]
    if lemma in DUAL_AUXILIARY_LEMMAS:
        auxiliary_variants.append((AVOIR_PRESENT, False, 20))

    for auxiliary_forms, agrees_with_subject, rank_offset in auxiliary_variants:
        for subject_rank, (subject, _, _) in enumerate(subjects_for_lemma(lemma)):
            participle = participle_for_subject(entry, subject, agrees_with_subject)
            phrase = f"{auxiliary_forms[subject]} {participle}"
            rows.append(
                (
                    lemma,
                    normalize(lemma),
                    phrase,
                    normalize(phrase),
                    "past_compound",
                    subject,
                    300 + rank_offset + subject_rank,
                    frequency,
                )
            )
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("morphalou_csv", type=Path)
    parser.add_argument("database", type=Path)
    parser.add_argument("--limit", type=int, default=405)
    arguments = parser.parse_args()

    entries = read_morphalou(arguments.morphalou_csv)
    database = sqlite3.connect(arguments.database)

    ranked = []
    for lemma, entry in entries.items():
        if any(character in lemma for character in (" ", "'", "’", "-")):
            continue
        if not has_complete_simple_tenses(lemma, entry):
            continue
        frequency = candidate_frequency(database, lemma)
        if frequency > 0:
            exact_frequency = exact_candidate_frequency(database, lemma)
            ranked.append((frequency, exact_frequency, lemma, entry))
    ranked.sort(key=lambda item: (-item[0], -item[1], normalize(item[2]), item[2]))

    selected = []
    selected_exact_frequencies = defaultdict(list)
    for item in ranked:
        _, exact_frequency, lemma, _ = item
        normalized = normalize(lemma)
        existing = selected_exact_frequencies[normalized]
        if existing and not (exact_frequency > 0 and any(value > 0 for value in existing)):
            continue
        selected.append(item)
        existing.append(exact_frequency)
        if len(selected) == arguments.limit:
            break

    database.executescript(
        """
        DROP TABLE IF EXISTS french_conjugations;
        CREATE TABLE french_conjugations (
            lemma TEXT NOT NULL,
            lemma_normalized TEXT NOT NULL,
            form TEXT NOT NULL,
            form_normalized TEXT NOT NULL,
            tense TEXT NOT NULL,
            subject TEXT NOT NULL,
            rank INTEGER NOT NULL,
            verb_frequency INTEGER NOT NULL,
            PRIMARY KEY (lemma, form, tense, subject)
        );
        CREATE INDEX idx_french_conjugations_lemma
            ON french_conjugations(lemma_normalized, rank, verb_frequency DESC);
        CREATE INDEX idx_french_conjugations_form
            ON french_conjugations(form_normalized, rank, verb_frequency DESC);
        CREATE INDEX idx_french_conjugations_subject
            ON french_conjugations(subject, lemma_normalized, rank);
        """
    )

    rows = []
    for frequency, _, lemma, entry in selected:
        rows.extend(create_rows(lemma, entry, frequency))
    database.executemany(
        """
        INSERT OR IGNORE INTO french_conjugations
            (lemma, lemma_normalized, form, form_normalized, tense, subject, rank, verb_frequency)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        rows,
    )
    database.commit()
    database.execute("VACUUM")

    verb_count, form_count = database.execute(
        "SELECT COUNT(DISTINCT lemma), COUNT(*) FROM french_conjugations"
    ).fetchone()
    database.close()
    if verb_count != arguments.limit:
        raise SystemExit(f"expected {arguments.limit} verbs, imported {verb_count}")
    print(f"Imported {verb_count} verbs and {form_count} contextual forms.")


if __name__ == "__main__":
    main()
