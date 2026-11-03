# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"

describe FloristImport::PeopleImporter do
  let(:csv_path) { HitobitoFlorist::Wagon.root.join("spec/fixtures/files/florist_import.csv") }
  let(:dir) { Pathname(Dir.mktmpdir) }
  let(:log_path) { dir.join("import.log") }
  let(:output) { StringIO.new }
  let(:dry_run) { false }
  let(:log) { File.read(log_path) }

  subject(:importer) { described_class.new(csv_path, dry_run:, log_path:, output:) }

  after { FileUtils.rm_rf(dir) }

  def imported_ids = Person.where(id: 1001..1011).order(:id).pluck(:id)

  def interessenten = Group::DachverbandKontakte.where(name: "Interessenten", parent: groups(:root))

  def record_counts
    [Person.count, Role.with_inactive.count, Group.count, Qualification.count,
      QualificationKind.count]
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
    described_class.new(path, log_path:, output:, force:).run
  end

  def next_person_id
    Person.connection.select_value("SELECT nextval(pg_get_serial_sequence('people', 'id'))")
  end

  it "imports the importable rows" do
    expect(importer.run).to eq true
    expect(imported_ids).to eq [1001, 1002, 1003, 1005, 1006, 1007]
    expect(importer.counts).to eq(total: 12, imported: 6, with_notes: 1, rejected: 5, skipped: 1)
  end

  describe "Personen" do
    before { importer.run }

    let(:erika) { Person.find(1001) }

    it "assigns person attributes and contact accounts" do
      expect(erika).to have_attributes(first_name: "Erika", last_name: "Muster", gender: "w",
        email: "erika@example.com", street: "Bahnhofstrasse", housenumber: "12",
        zip_code: "8001", town: "Zürich", country: "CH", canton: "zh",
        birthday: Date.new(1980, 12, 24), language: "de",
        additional_information: "zahlt bar\nLieferant", full_time_employee_count: 3,
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

    it "drops the canton outside of Switzerland" do
      expect(Person.find(1006)).to have_attributes(country: "DE", canton: nil)
    end
  end

  describe "Rollen" do
    before { importer.run }

    def roles_of(id)
      Role.with_inactive.where(person_id: id).map do |role|
        [role.type, role.group.name, role.start_on, role.end_on]
      end
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

    it "ends the active role and starts an ex member role at Austrittsdatum" do
      expect(roles_of(1005)).to match_array [
        ["Group::Sektion::Aktivmitglied", "Zürich", Date.new(2000, 1, 1), Date.new(2020, 12, 31)],
        ["Group::Sektion::ExMitglied", "Zürich", Date.new(2020, 12, 31), nil]
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
      expect(Role.where(person_id: 1003).map { |r| [r.type, r.group] })
        .to eq [["Group::DachverbandKontakte::Kontakt", interessenten.first]]
      expect(log).to include "Gruppe Interessenten unter florist.ch angelegt"
    end

    it "uses an existing group" do
      group = Group::DachverbandKontakte.create!(name: "Interessenten", parent: groups(:root))
      expect { importer.run }.not_to change { interessenten.count }
      expect(Role.find_by(person_id: 1003).group).to eq group
      expect(log).not_to include "angelegt"
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

    it "rejects a duplicate email of an earlier row" do
      expect(Person.exists?(1009)).to eq false
      expect(log).to include "Zeile 10 | Adressnumm 1009 | Erika Doppelt | ABGELEHNT\n" \
        "  - Email-Adre erika@example.com ist bereits vergeben"
    end

    it "rejects a duplicate id of an earlier row" do
      expect(Person.find(1001).first_name).to eq "Erika"
      expect(log).to include "Zeile 11 | Adressnumm 1001 | Nina Nochmals | ABGELEHNT\n" \
        "  - Adressnumm 1001 kommt mehrfach in der Datei vor\n"
    end

    it "rejects an invalid phone number with the original line" do
      expect(log).to include "Zeile 12 | Adressnumm 1010 | Tina Telefon | ABGELEHNT\n" \
        "  - Telefonnummer ist nicht gültig\n" \
        "  > 1010,,,Telefon,Tina,,__________,A_________________________,"
    end

    it "rejects Abteilung together with Adresszusatz" do
      expect(log).to include "Zeile 9 | Adressnumm 1008 | Karl Kollision | ABGELEHNT\n" \
        "  - c/o-Feld ist bereits durch Abteilung/ 'Einkauf' belegt"
    end

    it "logs the skipped deceased row with further codes" do
      expect(Person.exists?(1004)).to eq false
      expect(log).to include "Zeile 5 | Adressnumm 1004 | Otto Alt | ÜBERSPRUNGEN\n" \
        "  - Verstorben (Code 4 Mit 'V')\n" \
        "  > 1004,Herr,,Alt,Otto,,__________,A____________________V_X__,"
    end

    it "logs the note of an imported row without the original line" do
      expect(log).to include "Zeile 8 | Adressnumm 1007 | Lea Jung | HINWEIS\n" \
        "  - Abo-Code 4 (Jahresabo Jungfloristen) nicht importiert\n\n"
    end

    it "writes the summary to the log and the output" do
      summary = "Zusammenfassung\n  Total: 12\n  Importiert: 6 (davon mit Hinweis: 1)\n" \
        "  Abgelehnt: 5\n  Übersprungen: 1\n"
      expect(log).to end_with summary
      expect(output.string).to eq "#{summary}Log: #{log_path}\n"
    end
  end

  it "rejects a company salutation without company name" do
    content = File.read(csv_path).lines.first +
      "2001,Firma,,,,,,A,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,6.0,,,,,,,,,,,,,,,,,\n"
    described_class.new(write_csv(content), log_path:, output:).run
    expect(Person.exists?(2001)).to eq false
    expect(log).to include "Zeile 2 | Adressnumm 2001 |  | ABGELEHNT"
    expect(log).to include "Firmenname muss ausgefüllt werden"
  end

  describe "Zeilenweise Atomarität" do
    it "saves neither person nor roles if a role fails while saving" do
      allow_any_instance_of(Group::DachverbandAbonnemente::JahresaboMitglied)
        .to receive(:create_passes).and_raise("Boom")
      lines = File.read(csv_path).lines
      path = write_csv(lines[0] + lines[1] + lines[2])
      described_class.new(path, log_path:, output:).run
      expect(log).to include "Zeile 2 | Adressnumm 1001 | Erika Muster | ABGELEHNT\n" \
        "  - RuntimeError: Boom"
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
      expect(importer.counts[:imported]).to eq 6
    end

    it "logs the same rejections as a real run" do
      entries = ->(text) { text.lines.drop(2) }
      importer.run
      dry_log = log
      described_class.new(csv_path, log_path:, output:).run
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

    it "rejects an email with invalid format" do
      content = File.read(csv_path).lines.first +
        "2001,,,Test,Tom,,,A,,,,,,,,,,,,,,,,,,,,,,info@@blumen," \
        ",,,,,,,,,,,,,,,,6.0,,,,,,,,,,,,,,,,,\n"
      described_class.new(write_csv(content), log_path:, output:).run
      expect(Person.exists?(2001)).to eq false
      expect(log).to include "Zeile 2 | Adressnumm 2001 | Tom Test | ABGELEHNT\n" \
        "  - Haupt-E-Mail ist nicht gültig"
    end

    it "restores the validation type after the run" do
      importer.run
      expect(Truemail.configuration.default_validation_type).to eq validation_type
    end

    it "restores the validation type after an abort" do
      described_class.new(write_csv("Adressnumm\n1\n"), log_path:, output:).run
      expect(Truemail.configuration.default_validation_type).to eq validation_type
    end

    it "restores the validation type after an unexpected error" do
      allow(FloristImport::Groups).to receive(:resolve).and_raise("Boom")
      expect { importer.run }.to raise_error("Boom")
      expect(Truemail.configuration.default_validation_type).to eq validation_type
    end
  end

  it "counts csv records for the line numbers" do
    lines = File.read(csv_path).lines
    first = lines[1].sub("zahlt bar", "\"zahlt\nbar\"")
    path = write_csv(lines[0] + first + lines[9])
    described_class.new(path, log_path:, output:).run
    expect(Person.find(1001).additional_information).to start_with "zahlt\nbar"
    expect(log).to include "Zeile 3 | Adressnumm 1009 | Erika Doppelt | ABGELEHNT"
  end

  describe "bestehende IDs" do
    let!(:existing) do
      Person.create!(id: 1002, first_name: "Alt", email: "alt@example.com")
    end

    it "skips a person existing before the import" do
      importer.run
      expect(existing.reload.first_name).to eq "Alt"
      expect(log).to include "Zeile 3 | Adressnumm 1002 | Blumen Muster AG | ÜBERSPRUNGEN\n" \
        "  - Person 1002 existiert bereits\n"
      expect(importer.counts).to include(imported: 5, skipped: 2)
    end
  end

  it "rejects a duplicate of a rejected row" do
    import_lines(member(3001, "Erste", "Mobilnumme" => "abc"), member(3001, "Zweite"))
    expect(Person.exists?(3001)).to eq false
    expect(log).to include "Zeile 3 | Adressnumm 3001 | Zweite | ABGELEHNT\n" \
      "  - Adressnumm 3001 kommt mehrfach in der Datei vor\n"
  end

  it "keeps a qualification kind created for a rejected row" do
    expect do
      import_lines(member(3002, "Abgelehnt", "Mobilnumme" => "abc", "SKBEQ" => "x"),
        member(3003, "Importiert", "SKBEQ" => "x"))
    end.to change { QualificationKind.count }.by(1)
    expect(Person.find(3003).qualifications.map { |q| q.qualification_kind.label }).to eq ["SKBEQ"]
  end

  describe "Force-Import" do
    let(:force_importer) { described_class.new(csv_path, log_path:, output:, force: true) }
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
      expect(Role.with_inactive.where(person_id: 1001).map(&:type)).to match_array [
        "Group::Sektion::Aktivmitglied", "Group::DachverbandAbonnemente::JahresaboMitglied"
      ]
      expect(replaced.qualifications.map { |q| q.qualification_kind.label })
        .to match_array %w[SKBEQ Kursleiterin]
      expect(log).to include "Zeile 2 | Adressnumm 1001 | Erika Muster | HINWEIS\n" \
        "  - Bestehende Person 1001 ersetzt\n"
    end

    it "does not replace with a duplicate of the file" do
      force_importer.run
      expect(Person.find(1001).first_name).to eq "Erika"
      expect(log).to include "Zeile 11 | Adressnumm 1001 | Nina Nochmals | ABGELEHNT\n" \
        "  - Adressnumm 1001 kommt mehrfach in der Datei vor\n"
    end

    it "keeps the existing person if the row is rejected" do
      tina = Person.create!(id: 1010, first_name: "Alt", last_name: "Tina")
      force_importer.run
      expect(tina.reload).to have_attributes(first_name: "Alt", last_name: "Tina")
      expect(log).to include "Zeile 12 | Adressnumm 1010 | Tina Telefon | ABGELEHNT\n" \
        "  - Telefonnummer ist nicht gültig"
    end

    it "keeps an existing person with code V" do
      otto = Person.create!(id: 1004, first_name: "Alt", last_name: "Otto")
      force_importer.run
      expect(otto.reload.first_name).to eq "Alt"
      expect(log).to include "Zeile 5 | Adressnumm 1004 | Otto Alt | ÜBERSPRUNGEN\n" \
        "  - Verstorben (Code 4 Mit 'V')"
    end

    it "counts the replaced people in the summary" do
      force_importer.run
      expect(force_importer.counts).to include(imported: 6, replaced: 1, with_notes: 2)
      expect(log).to include "  Importiert: 6 (davon ersetzt: 1, mit Hinweis: 2)\n"
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
      described_class.new(csv_path, log_path:, output:, dry_run: true).run
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
      result = described_class.new(path, log_path:, output:).run
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
    expect(log).to include "Zeile 4 | Adressnumm 1003 | Hans Meier | ABGELEHNT\n" \
      "  - RuntimeError: Boom"
    expect(imported_ids).to eq [1001, 1002, 1005, 1006, 1007]
  end

  it "sends no mails" do
    expect { importer.run }.not_to change { ActionMailer::Base.deliveries.size }
  end
end
