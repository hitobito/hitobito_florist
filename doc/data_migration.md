# Data migration

The one-time import of the florist.ch people, roles and qualifications reads a single CSV file
with the original export header. Run it from the core directory:

```bash
bin/rake "florist:import_people:dryrun[path/to/export.csv]"
bin/rake "florist:import_people[path/to/export.csv]"
bin/rake "florist:import_people:force[path/to/export.csv]"
```

- `florist:import_people` skips rows whose `Adressnumm` already exists as person id.
- `florist:import_people:dryrun` processes and logs every row, then rolls everything back.
- `florist:import_people:force` deletes an existing person with the same id and imports the row
  again. All data of the deleted person is lost, including roles, notes or logins added after an
  earlier import. If the row is rejected, the existing person is kept.
- An optional second argument overrides the default log file
  `log/florist_import_<timestamp>.log`, e.g. `"florist:import_people[export.csv,import.log]"`.

The log lists every rejected or skipped row with its reasons and the original CSV line, notes on
imported rows and a summary. The import aborts before the first row if a required column, the
Abonnemente group or a mapped Sektion is missing. Rows repeating an `Adressnumm` of an earlier
row are rejected, as are rows whose email belongs to another person.

After a real run, the person id sequence continues at 400000 or above the highest person id,
whichever is greater.

During the run, email addresses are validated by format only, without a domain lookup. Addresses
with a non-existing domain are imported and only show up as bounces later.

The lookup tables for codes, sections, GV visits and salutations are in
`FloristImport::Mappings`.
