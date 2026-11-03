# Data migration

The one-time import of the florist.ch people, roles and qualifications reads a single CSV file
with the original export header. Run it from the core directory:

```bash
bin/rake "florist:import_people:dryrun[path/to/export.csv]"
bin/rake "florist:import_people[path/to/export.csv]"
bin/rake "florist:import_people:force[path/to/export.csv]"
```

- `florist:import_people` skips rows whose `Adressnumm` already exists as person id.
- `florist:import_people:dryrun` processes and reports every row, then rolls everything back.
- `florist:import_people:force` deletes an existing person with the same id and imports the row
  again. All data of the deleted person is lost, including roles, notes or logins added after an
  earlier import. If the row is rejected, the existing person is kept.
- An optional second argument overrides the default log file
  `log/florist_import_<timestamp>.log`, e.g. `"florist:import_people[export.csv,import.log]"`.
  The report is written next to it with the extension `.csv`.

While running, the tasks print the current phase and the progress (rows, counts and estimated
remaining time) to stderr. In a terminal the progress line is updated in place, otherwise a new
line is printed every 10 percent. The log file and the summary on stdout contain no progress.

The log file only contains the header (mode, file, report path, created groups) and the summary,
or the abort message. The CSV report has one row per rejected, skipped or noted contact with the
columns `Adressnumm`, `Status` (ABGELEHNT, ÜBERSPRUNGEN, HINWEIS), `Vorname`, `Nachname` and one
cell per message. It is UTF-8 and comma separated; open it in Excel via "Data → From Text/CSV"
rather than by double click, which splits at semicolons with Swiss regional settings.

Column names are matched regardless of case (e.g. `Code 3 Abo` and `Code 3 ABo`); two columns
differing only in case abort the import. The import also aborts before the first row if a required
column, the root user, the Abonnemente group, a mapped Sektion or one of the phone number categories
`business`, `mobile` and `private` is missing. Rows repeating an `Adressnumm` of an earlier row are
rejected. A person whose `Sektionszu` is empty or not mapped is imported without member roles and
tagged `Datenmigration:Sektion fehlt`.

Every imported person gets a Kontakt role in the group "Import Datenmigration" below the root
group. Code I adds a Kontakt role in "Interessenten", code X one in "Ex Mitglieder" starting the
day after `Austrittsd`. Missing contact groups are created. Rows with code V, U or G are skipped,
code N is ignored. `Abteilung/` and `Adresszusa` are joined into the c/o field, `TextBox` is not
imported, and `Mutationsd` is added as a note authored by the root user.

Dates (`Geburtstag`, `Eintrittsd`, `Austrittsd`, `Abo Beginn`, `Abo Ende`) must be in the
export format `YYYY-MM-DD`, other formats reject the row. `Sprachcode` 1 maps to German, 2 to
French and an empty value to German; other values reject the row.

`Telefon Ge` is imported as phone number of category `business`, `Mobilnumme` as `mobile` and
`Telefon Pr` as `private`. Invalid phone numbers and emails do not reject the row: the person is
imported without the value, tagged `Datenmigration:Telefonnummer ungültig` or
`Datenmigration:E-Mail ungültig` and gets a note like "Ungültige Telefonnummer Mobil: <value>". An
invalid Swiss canton is dropped. A main email already used by another person is imported as
additional email of category "other" with label "Duplikat". An invalid `Postleitza` is dropped,
tagged `Datenmigration:PLZ ungültig` and noted as "Ungültige PLZ: <value>". Each correction appears
as HINWEIS in the report.

After a real run, the person id sequence continues at 400000 or above the highest person id,
whichever is greater.

During the run, email addresses are validated by format only, without a domain lookup. Addresses
with a non-existing domain are imported. After a real run, tag and block them with:

```bash
bin/rake "validate:people_email[block]"
```

The tags of the import are named in German, so hitobito shows them grouped under "Datenmigration"
as "Telefonnummer ungültig", "E-Mail ungültig", "PLZ ungültig" and "Sektion fehlt" without
translation.

The lookup tables for codes, sections, GV visits, salutations and tags are in
`FloristImport::Mappings`.
