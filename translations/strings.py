#!/usr/bin/env python3
"""Translations as one table: translations/strings.csv, one row per distinct text, one column per language.

  python3 translations/strings.py export   # lupdate the sources, add new texts to strings.csv (keeps translations)

The texts come from qsTr() in QML and tr() / QT_TRANSLATE_NOOP in C++. A text used in several places is one row;
its translation applies to all of them. Plural rows hold the forms separated by " | ".
"""
import csv
import os
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV = os.path.join(ROOT, "translations", "strings.csv")
LANGUAGES = ["ru", "uk", "es", "pt_BR", "de", "fr"]
COLUMNS = ["text", "where", "note", "en"] + LANGUAGES


def scan():
    """[(text, contexts, note, plural, location)] in source order, one per distinct text."""
    with tempfile.TemporaryDirectory() as tmp:
        ts = os.path.join(tmp, "all.ts")
        subprocess.run(["lupdate", "src", "qml", "-extensions", "cpp,h,qml", "-source-language", "en",
                        "-locations", "absolute", "-no-obsolete", "-silent", "-ts", ts], cwd=ROOT, check=True)
        tree = ET.parse(ts)
    rows = {}
    order = []
    for context in tree.getroot().iter("context"):
        name = context.findtext("name")
        for m in context.iter("message"):
            text = m.findtext("source")
            loc = m.find("location")
            where = (loc.get("filename"), int(loc.get("line"))) if loc is not None else ("", 0)
            note = " ".join(x for x in (m.findtext("comment"), m.findtext("extracomment")) if x)
            if text not in rows:
                rows[text] = {"contexts": [], "notes": [], "plural": m.get("numerus") == "yes", "where": where}
                order.append(text)
            r = rows[text]
            if name not in r["contexts"]:
                r["contexts"].append(name)
            if note and note not in r["notes"]:
                r["notes"].append(note)
    # screen by screen: QML first (in file order), the C++ messages after
    order.sort(key=lambda t: (not rows[t]["where"][0].endswith(".qml"), rows[t]["where"]))
    return [(t, rows[t]) for t in order]


def english_plural(text):
    # "%n track(s)" -> "%n track | %n tracks"
    if "(s)" in text:
        return text.replace("(s)", "") + " | " + text.replace("(s)", "s")
    if text.endswith("s"):
        return text[:-1] + " | " + text
    return text


def export():
    existing = {}
    if os.path.exists(CSV):
        with open(CSV, encoding="utf-8-sig", newline="") as f:
            for row in csv.DictReader(f):
                existing[row["text"]] = row
    out = []
    for text, r in scan():
        notes = list(r["notes"])
        placeholders = [p for p in ("%1", "%2", "%n") if p in text]
        if r["plural"]:
            notes.append("PLURAL: forms separated by ' | ' (ru, uk: 3 forms for 1 / 2-4 / 5+; "
                         "es, pt_BR, de, fr: 2 forms for 1 / many)")
        if placeholders:
            notes.append("keep " + ", ".join(placeholders))
        row = {"text": text, "where": ", ".join(r["contexts"]), "note": "; ".join(notes),
               "en": english_plural(text) if r["plural"] else text}
        old = existing.get(text, {})
        for lang in ["en"] + LANGUAGES:
            if old.get(lang):
                row[lang] = old[lang]
        out.append(row)
    with open(CSV, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=COLUMNS, quoting=csv.QUOTE_ALL)
        w.writeheader()
        for row in out:
            w.writerow({c: row.get(c, "") for c in COLUMNS})
    gone = set(existing) - {row["text"] for row in out}
    print(f"{len(out)} texts in {os.path.relpath(CSV, ROOT)}" + (f", {len(gone)} no longer used: dropped" if gone else ""))


if __name__ == "__main__":
    if sys.argv[1:] == ["export"]:
        export()
    else:
        sys.exit(__doc__)
