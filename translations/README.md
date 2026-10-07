# Translations

`strings.csv` holds every text of the interface, one row per distinct English text, one column per language
(UTF-8; open it in LibreOffice Calc with "UTF-8" and "comma" as the separator, quoted fields as text).

- `text`: the source text in the code. Don't change it: it is how a row finds its places in the code.
- `where`: the screens / components that show it. `note`: what it is, placeholders to keep, plural rules.
- `en`: what English shows (already filled; edit it to change the English wording).
- `ru`, `uk`, `es`, `pt_BR`, `de`, `fr`: the translations. An empty cell shows the English text.
- `%1`, `%2`, `%n` are replaced by values (a name, a number): keep them, they may move within the sentence.
- Plural rows (`PLURAL` in the note) take every form separated by ` | `:
  ru, uk: three forms, for 1 / 2–4 / 5 and more (`%n трек | %n трека | %n треков`);
  es, pt_BR, de, fr: two forms, for 1 / more (`%n canción | %n canciones`).
- The window is a 1431×500 banner: buttons, tabs and badges have little room, so prefer short words there.

`python3 translations/strings.py export` scans the code again (needs `lupdate`) and adds new texts to the table,
keeping what is already translated.
