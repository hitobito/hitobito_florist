# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"

describe FloristImport::PeopleImporter, :with_truemail_validation do
  let(:csv_path) { HitobitoFlorist::Wagon.root.join("spec/fixtures/files/florist_import.csv") }
  let(:dir) { Pathname(Dir.mktmpdir) }
  let(:log_path) { dir.join("import.log") }
  let(:output) { StringIO.new }
  let(:progress) { StringIO.new }
  let(:dry_run) { false }
  let(:log) { File.read(log_path) }

  subject(:importer) { described_class.new(csv_path, dry_run:, log_path:, output:, progress:) }

  let!(:root_person) do
    Person.new(first_name: "Root", email: Settings.root_email).tap { |p| p.save!(validate: false) }
  end

  after { FileUtils.rm_rf(dir) }

  def imported_ids = Person.where(id: 1001..1020).order(:id).pluck(:id)

  def interessenten = Group::DachverbandKontakte.where(name: "Interessenten", parent: groups(:root))

  def record_counts
    [Person.count, Role.with_inactive.count, Group.count, Qualification.count,
      QualificationKind.count]
  end

  def report_path = Pathname(log_path).sub_ext(".csv")

  def report_rows = CSV.read(report_path, encoding: "UTF-8")

  def report_row(id) = report_rows.find { |row| row.first == id }

  def expect_report(id, status, *messages)
    rows = report_rows.select { |row| row.first == id }
    match = rows.find { |row| row[1] == status && (messages - row.drop(4)).empty? }
    expect(match).to be_present, "no #{status} report row for #{id} with #{messages}: #{rows}"
  end

  def write_csv(content)
    dir.join("custom.csv").tap { |path| File.write(path, content) }
  end

  def header_line = File.read(csv_path).lines.first

  def csv_line(values)
    CSV.generate_line(CSV.parse_line(header_line).map { |header| values[header] })
  end

  def member(id, name, **values)
    {"Adressnumm" => id.to_s, "Name" => name, "Code 4 Mit" => "A", "Sektionszu" => "6.0"}
      .merge(values.transform_keys(&:to_s))
  end

  def import_lines(*rows, force: false)
    path = write_csv(header_line + rows.map { |values| csv_line(values) }.join)
    described_class.new(path, log_path:, output:, progress:, force:).run
  end

  def next_person_id
    Person.connection.select_value("SELECT nextval(pg_get_serial_sequence('people', 'id'))")
  end

  it "imports the importable rows" do
    expect(importer.run).to eq true
    expect(imported_ids)
      .to eq [1001, 1002, 1003, 1005, 1006, 1007, 1008, 1009, 1010, 1014, 1015, 1016, 1017]
    expect(importer.counts).to eq(total: 18, imported: 13, with_notes: 7, rejected: 2, skipped: 3)
  end

  describe "Personen" do
    before { importer.run }

    let(:erika) { Person.find(1001) }

    it "assigns person attributes and contact accounts" do
      expect(erika).to have_attributes(first_name: "Erika", last_name: "Muster", gender: "w",
        email: "erika@example.com", street: "Bahnhofstrasse", housenumber: "12",
        zip_code: "8001", town: "Zürich", country: "CH", canton: "zh",
        birthday: Date.new(1980, 12, 24), language: "de",
        additional_information: "Lieferant", full_time_employee_count: 3,
        part_time_employee_count: 2, apprentice_count: 1, branch_count: 0,
        visited_gv_dachverband: true, visited_gv_sektion: true)
      expect(erika.phone_numbers.map { |p| [p.number, p.category.key, p.label] })
        .to match_array [["+41 44 668 18 01", "work", nil], ["+41 79 123 45 67", "mobile", nil],
          ["+41 44 668 18 00", "other", "Privat"]]
      expect(erika.additional_emails.map { |e| [e.email, e.category.key] })
        .to eq [["rechnung@example.com", "invoices"]]
      expect(erika.social_accounts.map(&:name)).to match_array %w[www.muster.ch www.blumen.ch]
    end

    it "imports a company with Abteilung as c/o" do
      expect(Person.find(1002)).to have_attributes(company: true,
        company_name: "Blumen Muster AG", address_care_of: "Einkauf", canton: "ag",
        visited_gv_dachverband: false, visited_gv_sektion: true)
    end

    it "joins Abteilung and Adresszusatz into c/o" do
      expect(Person.find(1008).address_care_of).to eq "Einkauf, c/o Hans Muster"
    end

    it "adds the Mutationsdatum as note of the root user" do
      expect(erika.notes.map { |n| [n.text, n.author] })
        .to eq [["Mutationsdatum: 2025-01-01", root_person]]
      expect(Person.find(1002).notes).to be_empty
    end

    it "maps the Sprachcode" do
      expect(Person.find(1005).language).to eq "fr"
      expect(Person.find(1003).language).to eq "de"
    end

    it "drops the canton outside of Switzerland" do
      expect(Person.find(1006)).to have_attributes(country: "DE", canton: nil)
    end
  end

  describe "Rollen" do
    before { importer.run }

    def roles_of(id)
      Role.with_inactive.where(person_id: id).map do |role|
        [role.type, role.group.name, role.start_on, role.end_on]
      end - [import_role]
    end

    let(:import_role) do
      ["Group::DachverbandKontakte::Kontakt", "Import Datenmigration", Time.zone.today, nil]
    end

    it "adds the Import Datenmigration role to every imported person" do
      roles = Role.with_inactive.joins(:group).where(groups: {name: "Import Datenmigration"})
      expect(roles.pluck(:person_id)).to match_array imported_ids
      expect(roles.map { |r| [r.type, r.start_on, r.end_on] }.uniq)
        .to eq [["Group::DachverbandKontakte::Kontakt", Time.zone.today, nil]]
    end

    it "imports a row without codes with the Import Datenmigration role only" do
      expect(roles_of(1015)).to be_empty
      expect(Role.with_inactive.where(person_id: 1015).count).to eq 1
    end

    it "ignores code N" do
      expect(roles_of(1014)).to eq [["Group::Sektion::Aktivmitglied", "Zürich", nil, nil]]
    end

    it "creates member and abo roles in different groups" do
      expect(roles_of(1001)).to match_array [
        ["Group::Sektion::Aktivmitglied", "Zürich", Date.new(2015, 3, 1), nil],
        ["Group::DachverbandAbonnemente::JahresaboMitglied", "Abonnemente",
          Date.new(2024, 1, 1), Date.new(2024, 12, 31)]
      ]
    end

    it "keeps an ended membership" do
      expect(roles_of(1002)).to eq [["Group::Sektion::Berufsmitglied", "Aargau",
        Date.new(2010, 1, 1), Date.new(2020, 12, 31)]]
    end

    it "ends the active role and starts Ex Mitglieder the day after Austritt" do
      expect(roles_of(1005)).to match_array [
        ["Group::Sektion::Aktivmitglied", "Zürich", Date.new(2000, 1, 1), Date.new(2020, 12, 31)],
        ["Group::DachverbandKontakte::Kontakt", "Ex Mitglieder", Date.new(2021, 1, 1), nil]
      ]
    end

    it "creates several abo roles without membership" do
      expect(roles_of(1006)).to match_array [
        ["Group::DachverbandAbonnemente::JahresaboSchweiz", "Abonnemente",
          Date.new(2024, 1, 1), nil],
        ["Group::DachverbandAbonnemente::Gratisabo", "Abonnemente",
          Date.new(2024, 1, 1), nil]
      ]
    end

    it "ignores abo code 4" do
      expect(roles_of(1007)).to eq [["Group::Sektion::Aktivmitglied", "Zürich", nil, nil]]
    end

    it "starts the Kontakt role of an interested person today" do
      expect(roles_of(1003)).to eq [["Group::DachverbandKontakte::Kontakt", "Interessenten",
        Time.zone.today, nil]]
    end
  end

  describe "Interessenten" do
    it "creates the group and logs it" do
      expect { importer.run }.to change { interessenten.count }.from(0).to(1)
      expect(Role.where(person_id: 1003, group: interessenten).map(&:type))
        .to eq ["Group::DachverbandKontakte::Kontakt"]
      expect(log).to include "Gruppe Interessenten unter florist.ch angelegt"
    end

    it "uses an existing group" do
      group = Group::DachverbandKontakte.create!(name: "Interessenten", parent: groups(:root))
      expect { importer.run }.not_to change { interessenten.count }
      expect(Role.where(person_id: 1003).map(&:group)).to include group
      expect(log).not_to include "Gruppe Interessenten"
    end
  end

  describe "Kontakte-Gruppen" do
    def contact_group(name) = Group::DachverbandKontakte.where(name:, parent: groups(:root))

    it "creates Ex Mitglieder and Import Datenmigration and logs them" do
      importer.run
      expect(contact_group("Ex Mitglieder").count).to eq 1
      expect(contact_group("Import Datenmigration").count).to eq 1
      expect(log).to include "Gruppe Ex Mitglieder unter florist.ch angelegt"
      expect(log).to include "Gruppe Import Datenmigration unter florist.ch angelegt"
    end

    it "uses existing groups" do
      Group::DachverbandKontakte.create!(name: "Ex Mitglieder", parent: groups(:root))
      Group::DachverbandKontakte.create!(name: "Import Datenmigration", parent: groups(:root))
      importer.run
      expect(contact_group("Ex Mitglieder").count).to eq 1
      expect(contact_group("Import Datenmigration").count).to eq 1
      expect(log).not_to include "Gruppe Ex Mitglieder"
    end

    it "aborts without root user" do
      allow(Person).to receive(:root).and_return(nil)
      expect(importer.run).to eq false
      expect(imported_ids).to be_empty
      expect(log).to include "Import abgebrochen: Root-User #{Settings.root_email} nicht gefunden"
    end
  end

  describe "Qualifikationen" do
    it "creates missing kinds once and assigns them" do
      expect { importer.run }.to change { QualificationKind.count }.by(2)
      kursleiterin = QualificationKind.find_by(label: "Kursleiterin")
      expect(kursleiterin.validity).to be_nil
      expect(Qualification.where(qualification_kind: kursleiterin).pluck(:person_id))
        .to match_array [1001, 1002]
      expect(Person.find(1001).qualifications.map { |q| [q.qualification_kind.label, q.finish_at] })
        .to match_array [["SKBEQ", nil], ["Kursleiterin", nil]]
    end

    it "uses an existing kind" do
      kind = QualificationKind.create!(label: "SKBEQ")
      expect { importer.run }.to change { QualificationKind.count }.by(1)
      expect(Person.find(1001).qualifications.map(&:qualification_kind)).to include kind
    end
  end

  describe "Ablehnungen" do
    before { importer.run }

    it "imports a duplicate email of an earlier row as additional email" do
      doppelt = Person.find(1009)
      expect(doppelt.email).to be_nil
      expect(doppelt.additional_emails.map { |e| [e.email, e.category.key, e.label] })
        .to eq [["erika@example.com", "other", "Duplikat"]]
      expect(doppelt.tag_list).to be_empty
      expect_report("1009", "HINWEIS", "Email-Adre erika@example.com ist bereits vergeben und " \
        "wurde als zusätzliche E-Mail \"Duplikat\" übernommen")
    end

    it "rejects a duplicate id of an earlier row" do
      expect(Person.find(1001).first_name).to eq "Erika"
      expect_report("1001", "ABGELEHNT", "Adressnumm 1001 kommt mehrfach in der Datei vor")
    end

    it "imports an invalid phone number as tag and note" do
      tina = Person.find(1010)
      expect(tina.phone_numbers).to be_empty
      expect(tina.tag_list).to eq ["import:data-invalid"]
      expect(tina.notes.map { |n| [n.text, n.author] })
        .to eq [["Ungültige Telefonnummer Mobil: abc", root_person]]
      expect_report("1010", "HINWEIS", "Mobilnumme 'abc' ist ungültig und wurde nicht übernommen")
    end

    it "imports an invalid canton without canton" do
      expect(Person.find(1014).canton).to be_nil
      expect_report("1014", "HINWEIS", "Kanton 'xx' ist ungültig und wurde nicht übernommen")
    end

    it "imports a person without section without member role" do
      olga = Person.find(1016)
      expect(olga.tag_list).to eq ["import:missing-section"]
      expect(Role.where(person_id: 1016).map(&:type)).to match_array [
        "Group::DachverbandAbonnemente::JahresaboSchweiz", "Group::DachverbandKontakte::Kontakt"
      ]
      expect_report("1016", "HINWEIS",
        "Sektionszu '' ist nicht zugeordnet, ohne Mitgliederrolle importiert")
    end

    it "imports an invalid zip code as tag and note" do
      paul = Person.find(1017)
      expect(paul.zip_code).to be_nil
      expect(paul.tag_list).to eq ["import:invalid-plz"]
      expect(paul.notes.map(&:text)).to eq ["Ungültige PLZ: 80011"]
      expect_report("1017", "HINWEIS", "Postleitza '80011' ist ungültig und wurde nicht übernommen")
    end

    it "imports an invalid invoice email as tag and note" do
      otto = Person.find(1015)
      expect(otto.additional_emails).to be_empty
      expect(otto.tag_list).to eq ["import:data-invalid"]
      expect(otto.notes.map(&:text)).to eq ["Ungültige E-Mail RG: rechnung@@blumen"]
    end

    it "logs the skipped rows with code U and G" do
      expect(Person.where(id: [1012, 1013])).to be_empty
      expect_report("1012", "ÜBERSPRUNGEN", "Ungültig (Code 4 Mit 'U')")
      expect_report("1013", "ÜBERSPRUNGEN", "Übersprungen (Code 4 Mit 'G')")
    end

    it "logs the skipped deceased row with further codes" do
      expect(Person.exists?(1004)).to eq false
      expect_report("1004", "ÜBERSPRUNGEN", "Verstorben (Code 4 Mit 'V')")
    end

    it "logs the note of an imported row without the original line" do
      expect_report("1007", "HINWEIS", "Abo-Code 4 (Jahresabo Jungfloristen) nicht importiert")
    end

    it "writes the summary to the log and the output" do
      summary = "Zusammenfassung\n  Total: 18\n  Importiert: 13 (davon mit Hinweis: 7)\n" \
        "  Abgelehnt: 2\n  Übersprungen: 3\n"
      expect(log).to end_with summary
      expect(output.string).to eq "#{summary}Log: #{log_path}\nReport: #{report_path}\n"
    end
  end

  it "rejects a company salutation without company name" do
    content = File.read(csv_path).lines.first +
      "2001,Firma,,,,,,A,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,6.0,,,,,,,,,,,,,,,,,\n"
    described_class.new(write_csv(content), log_path:, output:, progress:).run
    expect(Person.exists?(2001)).to eq false
    expect_report("2001", "ABGELEHNT")
    expect(report_row("2001").drop(4).join).to include "Firmenname muss ausgefüllt werden"
  end

  describe "Zeilenweise Atomarität" do
    it "saves neither person nor roles if a role fails while saving" do
      allow_any_instance_of(Group::DachverbandAbonnemente::JahresaboMitglied)
        .to receive(:create_passes).and_raise("Boom")
      lines = File.read(csv_path).lines
      path = write_csv(lines[0] + lines[1] + lines[2])
      described_class.new(path, log_path:, output:, progress:).run
      expect_report("1001", "ABGELEHNT", "RuntimeError: Boom")
      expect(Person.exists?(1001)).to eq false
      expect(Role.with_inactive.where(person_id: 1001)).to be_empty
      expect(imported_ids).to eq [1002]
    end
  end

  describe "Probelauf" do
    let(:dry_run) { true }

    it "persists nothing" do
      expect { importer.run }.not_to change { record_counts }
      expect(log).to start_with "Florist Import (Probelauf)"
      expect(importer.counts[:imported]).to eq 13
    end

    it "logs the same rejections as a real run" do
      entries = ->(text) { text.lines.drop(2) }
      importer.run
      dry_log = log
      described_class.new(csv_path, log_path:, output:, progress:).run
      expect(entries.call(dry_log)).to eq entries.call(log)
    end
  end

  describe "E-Mail-Prüfung", :with_truemail_validation do
    let!(:validation_type) { Truemail.configuration.default_validation_type }

    it "validates emails by format only during the run" do
      types = []
      allow(Truemail).to receive(:valid?).and_wrap_original do |original, *args, **options|
        types << Truemail.configuration.default_validation_type
        original.call(*args, **options)
      end
      importer.run
      expect(types).to be_present
      expect(types.uniq).to eq [:regex]
    end

    it "imports an email whose domain has no mail server" do
      importer.run
      expect(Person.find(1002).email).to eq "info@blumen-muster.invalid"
    end

    it "imports an email with invalid format as tag and note" do
      content = File.read(csv_path).lines.first +
        "2001,,,Test,Tom,,,A,,,,,,,,,,,,,,,,,,,,,,info@@blumen," \
        ",,,,,,,,,,,,,,,,6.0,,,,,,,,,,,,,,,,,\n"
      described_class.new(write_csv(content), log_path:, output:, progress:).run
      tom = Person.find(2001)
      expect(tom.email).to be_nil
      expect(tom.tag_list).to eq ["import:data-invalid"]
      expect(tom.notes.map(&:text)).to eq ["Ungültige Email: info@@blumen"]
    end

    it "restores the validation type after the run" do
      importer.run
      expect(Truemail.configuration.default_validation_type).to eq validation_type
    end

    it "restores the validation type after an abort" do
      described_class.new(write_csv("Adressnumm\n1\n"), log_path:, output:, progress:).run
      expect(Truemail.configuration.default_validation_type).to eq validation_type
    end

    it "restores the validation type after an unexpected error" do
      allow(FloristImport::Groups).to receive(:resolve).and_raise("Boom")
      expect { importer.run }.to raise_error("Boom")
      expect(Truemail.configuration.default_validation_type).to eq validation_type
    end
  end

  it "imports a cell with a line break" do
    lines = File.read(csv_path).lines
    first = lines[1].sub("Lieferant", "\"Liefer\nant\"")
    path = write_csv(lines[0] + first + lines[10])
    described_class.new(path, log_path:, output:, progress:).run
    expect(Person.find(1001).additional_information).to eq "Liefer\nant"
    expect_report("1001", "ABGELEHNT")
  end

  describe "bestehende IDs" do
    let!(:existing) do
      Person.create!(id: 1002, first_name: "Alt", email: "alt@example.com")
    end

    it "skips a person existing before the import" do
      importer.run
      expect(existing.reload.first_name).to eq "Alt"
      expect_report("1002", "ÜBERSPRUNGEN", "Person 1002 existiert bereits")
      expect(importer.counts).to include(imported: 12, skipped: 4)
    end
  end

  it "imports an email of an existing person as duplicate" do
    Person.create!(first_name: "Bestehend", email: "hans@example.com")
    importer.run
    hans = Person.find(1003)
    expect(hans.email).to be_nil
    expect(hans.additional_emails.map { |e| [e.email, e.label] })
      .to eq [["hans@example.com", "Duplikat"]]
  end

  it "rejects a duplicate of a rejected row" do
    import_lines(member(3001, "Erste", "Geburtstag" => "irgendwann"), member(3001, "Zweite"))
    expect(Person.exists?(3001)).to eq false
    expect_report("3001", "ABGELEHNT", "Adressnumm 3001 kommt mehrfach in der Datei vor")
  end

  it "keeps a qualification kind created for a rejected row" do
    expect do
      import_lines(member(3002, "Abgelehnt", "Geburtstag" => "irgendwann", "SKBEQ" => "x"),
        member(3003, "Importiert", "SKBEQ" => "x"))
    end.to change { QualificationKind.count }.by(1)
    expect(Person.find(3003).qualifications.map { |q| q.qualification_kind.label }).to eq ["SKBEQ"]
  end

  describe "Force-Import" do
    let(:force_importer) do
      described_class.new(csv_path, log_path:, output:, progress:, force: true)
    end
    let!(:erika) do
      Person.create!(id: 1001, first_name: "Alt", last_name: "Erika", email: "erika@example.com")
    end

    before do
      Group::Sektion::Passivmitglied.create!(person: erika, group: groups(:aargau))
    end

    it "replaces an existing person with the data of the row" do
      force_importer.run
      replaced = Person.find(1001)
      expect(replaced).to have_attributes(first_name: "Erika", last_name: "Muster",
        email: "erika@example.com")
      expect(Role.with_inactive.where(person_id: 1001).map { |r| [r.type, r.group.name] })
        .to match_array [
          ["Group::Sektion::Aktivmitglied", "Zürich"],
          ["Group::DachverbandAbonnemente::JahresaboMitglied", "Abonnemente"],
          ["Group::DachverbandKontakte::Kontakt", "Import Datenmigration"]
        ]
      expect(replaced.notes.map(&:text)).to eq ["Mutationsdatum: 2025-01-01"]
      expect(replaced.qualifications.map { |q| q.qualification_kind.label })
        .to match_array %w[SKBEQ Kursleiterin]
      expect_report("1001", "HINWEIS", "Bestehende Person 1001 ersetzt")
    end

    it "does not replace with a duplicate of the file" do
      force_importer.run
      expect(Person.find(1001).first_name).to eq "Erika"
      expect_report("1001", "ABGELEHNT", "Adressnumm 1001 kommt mehrfach in der Datei vor")
    end

    it "keeps the existing person if the row is rejected" do
      anna = Person.create!(id: 1011, first_name: "Alt", last_name: "Anna")
      force_importer.run
      expect(anna.reload).to have_attributes(first_name: "Alt", last_name: "Anna")
      expect_report("1011", "ABGELEHNT", "Code 3 Abo '0' ist unbekannt")
    end

    it "keeps an existing person with code V" do
      otto = Person.create!(id: 1004, first_name: "Alt", last_name: "Otto")
      force_importer.run
      expect(otto.reload.first_name).to eq "Alt"
      expect_report("1004", "ÜBERSPRUNGEN", "Verstorben (Code 4 Mit 'V')")
    end

    it "counts the replaced people in the summary" do
      force_importer.run
      expect(force_importer.counts).to include(imported: 13, replaced: 1, with_notes: 8)
      expect(log).to include "  Importiert: 13 (davon ersetzt: 1, mit Hinweis: 8)\n"
    end
  end

  describe "ID-Sequenz" do
    after { Person.connection.reset_pk_sequence!("people") }

    it "sets the next id to at least 400000" do
      allow(Person).to receive(:maximum).and_call_original
      allow(Person).to receive(:maximum).with(:id).and_return(12_345)
      importer.run
      expect(next_person_id).to eq 400_000
    end

    it "sets the next id above the highest id" do
      allow(Person).to receive(:maximum).and_call_original
      allow(Person).to receive(:maximum).with(:id).and_return(512_345)
      importer.run
      expect(next_person_id).to eq 512_346
    end

    it "keeps the sequence in a dry run" do
      sequence_state = -> {
        Person.connection.select_rows("SELECT last_value, is_called FROM people_id_seq")
      }
      before = sequence_state.call
      described_class.new(csv_path, log_path:, output:, progress:, dry_run: true).run
      expect(sequence_state.call).to eq before
    end
  end

  it "moves the id sequence above the imported ids" do
    Person.connection.execute("SELECT setval(pg_get_serial_sequence('people', 'id'), 1)")
    importer.run
    highest_id = Person.maximum(:id)
    expect(Person.create!(first_name: "Neu").id).to be > highest_id
  end

  describe "Abbruch vor der ersten Zeile" do
    it "aborts on missing columns" do
      header = File.read(csv_path).lines.first.sub(",Sektionszu", "").sub(",Kanton,", ",")
      path = write_csv("#{header}9999,Herr,,Test,Tom,,,A\n")
      result = described_class.new(path, log_path:, output:, progress:).run
      expect(result).to eq false
      expect(Person.exists?(9999)).to eq false
      expect(log).to include "Import abgebrochen: Fehlende Spalten: Kanton, Sektionszu"
      expect(output.string).to include "Import abgebrochen: Fehlende Spalten: Kanton, Sektionszu"
    end

    it "aborts if a mapped section does not exist" do
      stub_const("FloristImport::Mappings::SECTIONS", {"6" => "Zürich", "9" => "Atlantis"})
      expect(importer.run).to eq false
      expect(imported_ids).to be_empty
      expect(log).to include "Import abgebrochen: Sektionen nicht gefunden: Atlantis"
    end
  end

  it "catches unexpected errors per row and continues" do
    allow_any_instance_of(Person).to receive(:save).and_wrap_original do |original, **options|
      raise "Boom" if original.receiver.id == 1003

      original.call(**options)
    end
    importer.run
    expect_report("1003", "ABGELEHNT", "RuntimeError: Boom")
    expect(imported_ids)
      .to eq [1001, 1002, 1005, 1006, 1007, 1008, 1009, 1010, 1014, 1015, 1016, 1017]
  end

  describe "Fortschrittsanzeige" do
    it "shows the phases and the progress of a real run" do
      importer.run
      lines = progress.string.lines.map(&:chomp)
      expect(lines.first(3)).to eq ["Datei wird gelesen …", "Gruppen werden geprüft …",
        "18 Zeilen werden importiert …"]
      expect(lines.grep(/^Zeilen /).last).to start_with "Zeilen 18/18 (100%) | importiert 13 | " \
        "abgelehnt 2 | übersprungen 3 |"
      expect(lines.last).to eq "ID-Sequenz wird gesetzt …"
    end

    it "shows the rollback in a dry run" do
      described_class.new(csv_path, log_path:, output:, progress:, dry_run: true).run
      expect(progress.string.lines.last).to eq "Probelauf wird zurückgerollt …\n"
      expect(progress.string).not_to include "ID-Sequenz"
    end

    it "ends with the last phase on an abort" do
      described_class.new(write_csv("Adressnumm\n1\n"), log_path:, output:, progress:).run
      expect(progress.string).to eq "Datei wird gelesen …\n"
      expect(output.string).to start_with "Import abgebrochen: Fehlende Spalten"
    end

    it "keeps progress out of the log and the summary" do
      importer.run
      expect(log).not_to include "Zeilen 18/18"
      expect(log).not_to include "wird gelesen"
      expect(output.string).not_to include "Zeilen 18/18"
    end
  end

  describe "Spaltennamen" do
    it "reads columns regardless of case" do
      lines = File.read(csv_path).lines
      path = write_csv(lines[0].sub("Code 3 Abo", "Code 3 ABo") + lines[1])
      described_class.new(path, log_path:, output:, progress:).run
      expect(Role.with_inactive.where(person_id: 1001).map(&:type))
        .to include "Group::DachverbandAbonnemente::JahresaboMitglied"
    end

    it "reads columns written in a different case throughout" do
      lines = File.read(csv_path).lines
      header = lines[0].sub("Adressnumm", "ADRESSNUMM").sub("Email-Adre", "email-adre")
      described_class.new(write_csv(header + lines[1]), log_path:, output:, progress:).run
      expect(Person.find(1001).email).to eq "erika@example.com"
    end

    it "reports missing columns with the expected name" do
      header = File.read(csv_path).lines.first.sub(",Hausnummer,", ",")
      result = described_class.new(write_csv("#{header}1\n"), log_path:, output:, progress:).run
      expect(result).to eq false
      expect(log).to include "Import abgebrochen: Fehlende Spalten: Hausnummer"
    end

    it "aborts on columns differing only in case" do
      header = File.read(csv_path).lines.first.chomp + ",Code 3 ABo\n"
      result = described_class.new(write_csv("#{header}1\n"), log_path:, output:, progress:).run
      expect(result).to eq false
      expect(log).to include "Import abgebrochen: Spalten mehrfach vorhanden: " \
        "Code 3 Abo, Code 3 ABo"
    end
  end

  describe "Logfile und Report" do
    it "keeps rows out of the log" do
      importer.run
      expect(log).to start_with "Florist Import (Import)"
      expect(log).to include "Report: #{report_path}"
      expect(log).not_to include "Adressnumm"
      expect(log).to end_with "Übersprungen: 3\n"
    end

    it "writes header and abort message to the log on an abort" do
      described_class.new(write_csv("Adressnumm\n1\n"), log_path:, output:, progress:).run
      expect(log.lines.size).to eq 5
      expect(log).to include "Import abgebrochen: Fehlende Spalten"
      expect(report_rows).to eq [%w[Adressnumm Status Vorname Nachname Meldungen]]
    end

    it "writes a report row per rejected, skipped or noted row" do
      importer.run
      expect(report_rows.first).to eq %w[Adressnumm Status Vorname Nachname Meldungen]
      expect(report_row("1011")).to eq ["1011", "ABGELEHNT", "Anna", "Abo",
        "Code 3 Abo '0' ist unbekannt"]
      expect(report_rows.size).to eq 1 + 2 + 3 + 7
    end

    it "leaves rows without findings out of the report" do
      importer.run
      expect(report_row("1002")).to be_nil
    end

    it "writes the report in a dry run" do
      described_class.new(csv_path, log_path:, output:, progress:, dry_run: true).run
      expect(report_row("1011")[1]).to eq "ABGELEHNT"
    end
  end

  it "sends no mails" do
    expect { importer.run }.not_to change { ActionMailer::Base.deliveries.size }
  end
end
