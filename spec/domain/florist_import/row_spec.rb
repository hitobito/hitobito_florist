# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"

describe FloristImport::Row do
  let(:headers) { FloristImport::Mappings::REQUIRED_HEADERS + ["Landeskenn"] }
  let(:base_values) do
    {"Adressnumm" => "4711", "Vorname" => "Erika", "Name" => "Muster",
     "Code 4 Mit" => mit("A"), "Sektionszu" => "6.0"}
  end
  let(:values) { {} }
  let(:import_groups) do
    FloristImport::Groups.new(
      sections: {"6" => groups(:zuerich)},
      abonnemente: groups(:abonnemente),
      interessenten: groups(:kontakte)
    )
  end
  let(:no_role_error) do
    "Keine Rolle: Code 4 Mit und Code 3 ABo ergeben keine importierbare Rolle"
  end

  subject(:row) { build_row(base_values.merge(values)) }

  def build_row(data)
    csv_row = CSV::Row.new(headers, headers.map { |header| data[header] })
    described_class.new(csv_row, line: 7, groups: import_groups)
  end

  def attrs = row.person_attributes

  def role_types = row.roles.pluck(:type)

  def mit(*codes) = bitmap(("A".."Z").to_a, codes)

  def abo(*codes) = bitmap(("0".."9").to_a, codes)

  def bitmap(positions, codes) = positions.map { |p| codes.include?(p) ? p : "_" }.join

  describe "Mitgliedernummer" do
    it "becomes the id" do
      expect(row.id).to eq 4711
      expect(row.errors).to be_empty
    end

    it "accepts integral decimals" do
      values["Adressnumm"] = "4711.0"
      expect(row.id).to eq 4711
    end

    it "is required" do
      values["Adressnumm"] = nil
      expect(row.id).to be_nil
      expect(row.errors).to eq ["Adressnumm fehlt"]
    end

    it "must be numeric" do
      values["Adressnumm"] = "A12"
      expect(row.errors).to eq ["Adressnumm 'A12' ist keine ganze Zahl"]
    end
  end

  describe "Name und Firma" do
    it "maps a company contact" do
      values.merge!("Vorname" => nil, "Name" => nil, "Firma" => "Blumen Muster AG")
      expect(attrs).to include("company" => true, "company_name" => "Blumen Muster AG")
      expect(attrs).not_to have_key("first_name")
      expect(attrs).not_to have_key("last_name")
      expect(row.name).to eq "Blumen Muster AG"
    end

    it "flags salutation Firma as company without company name" do
      values["Anrede"] = "Firma"
      expect(attrs).to include("company" => true)
      expect(attrs).not_to have_key("company_name")
    end

    it "flags a person with company address as company" do
      values.merge!("Anrede" => "Frau", "Firma" => "Blumen Muster AG")
      expect(attrs).to include("company" => true, "first_name" => "Erika",
        "last_name" => "Muster", "company_name" => "Blumen Muster AG")
      expect(row.name).to eq "Erika Muster"
    end

    it "does not flag a person without company" do
      expect(attrs).to include("company" => false)
    end
  end

  describe "Geschlecht aus Anrede" do
    genders = {"Herr" => "m", "frau" => "w", "Madame" => "w", "Rechtsanwältin" => "w"}
    genders.each do |anrede, gender|
      it "maps #{anrede} to #{gender}" do
        values["Anrede"] = anrede
        expect(attrs["gender"]).to eq gender
      end
    end

    it "leaves gender empty for unknown salutation" do
      values["Anrede"] = "Familie"
      expect(attrs).not_to have_key("gender")
      expect(row.errors).to be_empty
    end
  end

  describe "Adress- und Personendaten" do
    it "maps the structured address" do
      values.merge!("Strasse/Nu" => "Bahnhofstrasse", "Hausnummer" => "12",
        "Postfach" => "Postfach 3", "Postleitza" => "8001", "Ortschaft" => "Zürich",
        "Land" => "CH", "Kanton" => "ZH")
      expect(attrs).to include("street" => "Bahnhofstrasse", "housenumber" => "12",
        "postbox" => "Postfach 3", "zip_code" => "8001", "town" => "Zürich", "country" => "CH",
        "canton" => "zh")
    end

    it "ignores Landeskenn" do
      values.merge!("Land" => "CH", "Landeskenn" => "D")
      expect(attrs["country"]).to eq "CH"
    end

    it "maps birthday and language" do
      values.merge!("Geburtstag" => "24.12.1980", "Sprachcode" => "FR")
      expect(attrs).to include("birthday" => Date.new(1980, 12, 24), "language" => "fr")
    end

    it "rejects a birthday in another format" do
      values["Geburtstag"] = "1980-12-24"
      expect(attrs).not_to have_key("birthday")
      expect(row.errors).to eq ["Geburtstag '1980-12-24' ist kein Datum im Format TT.MM.JJJJ"]
    end
  end

  describe "c/o-Feld" do
    it "takes Abteilung" do
      values["Abteilung/"] = "Einkauf"
      expect(attrs["address_care_of"]).to eq "Einkauf"
    end

    it "takes Adresszusatz" do
      values["Adresszusa"] = "c/o Hans Muster"
      expect(attrs["address_care_of"]).to eq "c/o Hans Muster"
    end

    it "rejects Abteilung together with Adresszusatz" do
      values.merge!("Abteilung/" => "Einkauf", "Adresszusa" => "c/o Hans Muster")
      expect(row.errors).to eq ["c/o-Feld ist bereits durch Abteilung/ 'Einkauf' belegt, " \
        "Adresszusa 'c/o Hans Muster' kann nicht übernommen werden"]
    end
  end

  describe "Notizen" do
    it "joins the non-empty note columns" do
      values.merge!("TextBox" => "zahlt bar", "Zusatzfeld.1" => "Lieferant", "Zusatzfeld" => " ")
      expect(attrs["additional_information"]).to eq "zahlt bar\nLieferant"
    end

    it "is absent without notes" do
      expect(attrs).not_to have_key("additional_information")
    end
  end

  describe "Kontaktangaben" do
    it "maps phone numbers, emails and homepage" do
      values.merge!("Email-Adre" => "Erika@Example.com", "Telefon Pr" => "044 111 11 11",
        "Telefon Ge" => "044 222 22 22", "Mobilnumme" => "079 333 33 33",
        "E-Mail RG" => "rechnung@example.com", "Homepage" => "www.muster.ch",
        "Zusatz Ema" => "privat@example.com")
      expect(attrs).to include("email" => "erika@example.com",
        "phone_number_work" => "044 222 22 22",
        "phone_number_mobile" => "079 333 33 33",
        "additional_email_invoices" => "rechnung@example.com",
        "additional_email_private" => "privat@example.com",
        "social_account_website" => "www.muster.ch")
      expect(attrs).not_to have_key("phone_number_landline")
      expect(row.private_phone).to eq "044 111 11 11"
      expect(row.additional_websites).to be_empty
    end

    it "maps Zusatz Ema without @ as website" do
      values["Zusatz Ema"] = "www.blumen.ch"
      expect(attrs["social_account_website"]).to eq "www.blumen.ch"
      expect(attrs).not_to have_key("additional_email_private")
      expect(row.additional_websites).to be_empty
    end

    it "keeps Zusatz Ema without @ as additional website next to Homepage" do
      values.merge!("Zusatz Ema" => "www.blumen.ch", "Homepage" => "www.muster.ch")
      expect(attrs["social_account_website"]).to eq "www.muster.ch"
      expect(row.additional_websites).to eq ["www.blumen.ch"]
    end
  end

  describe "Mitarbeitende-Zahlen" do
    it "maps the counts" do
      values.merge!("Anzahl Vol" => "3", "Anzahl Tei" => "2.0", "Anzahl Aus" => "1",
        "Anzahl Fil" => "4")
      expect(attrs).to include("full_time_employee_count" => 3, "part_time_employee_count" => 2,
        "apprentice_count" => 1, "branch_count" => 4)
    end

    it "treats empty counts as 0" do
      expect(attrs["branch_count"]).to eq 0
    end

    it "rejects non-integer counts" do
      values["Anzahl Fil"] = "zwei"
      expect(row.errors).to eq ["Anzahl Fil 'zwei' ist keine ganze Zahl"]
    end
  end

  describe "GV-Besuch" do
    {
      "0.0" => [false, false], "1.0" => [true, false], "2.0" => [false, true], "3" => [true, true]
    }.each do |visit, (dachverband, sektion)|
      it "maps #{visit}" do
        values["GV Besuch"] = visit
        expect(attrs).to include("visited_gv_dachverband" => dachverband,
          "visited_gv_sektion" => sektion)
      end
    end

    it "sets both to false when empty" do
      expect(attrs).to include("visited_gv_dachverband" => false, "visited_gv_sektion" => false)
    end

    it "rejects an unknown value" do
      values["GV Besuch"] = "4.0"
      expect(row.errors).to eq ["GV Besuch '4' ist nicht zugeordnet"]
    end
  end

  describe "Codes" do
    it "reads every character except _ as code" do
      values["Code 4 Mit"] = "A______________________X__"
      expect(role_types).to eq [Group::Sektion::Aktivmitglied, Group::Sektion::ExMitglied]
    end

    it "reads only underscores as no code" do
      values.merge!("Code 4 Mit" => mit, "Sektionszu" => nil, "Code 3 ABo" => "__________")
      expect(row.roles).to be_empty
      expect(row.errors).to eq [no_role_error]
    end
  end

  describe "Mitgliederrolle" do
    %w[A R Q].each do |code|
      it "maps #{code} to Aktivmitglied" do
        values.merge!("Code 4 Mit" => mit(code), "Eintrittsd" => "01.03.2015")
        expect(row.roles).to eq [{group: groups(:zuerich), type: Group::Sektion::Aktivmitglied,
                                  start_on: Date.new(2015, 3, 1), end_on: nil}]
      end
    end

    {
      "B" => Group::Sektion::Berufsmitglied,
      "C" => Group::Sektion::Berufsmitgliedplus,
      "D" => Group::Sektion::StartUp,
      "E" => Group::Sektion::Ehrenmitglied,
      "F" => Group::Sektion::Filiale,
      "H" => Group::Sektion::Entdecker,
      "L" => Group::Sektion::Partnermitglied,
      "P" => Group::Sektion::Passivmitglied
    }.each do |code, type|
      it "maps #{code} to #{type.name.demodulize}" do
        values["Code 4 Mit"] = mit(code)
        expect(role_types).to eq [type]
      end
    end

    it "creates a role per code with the same dates" do
      values.merge!("Code 4 Mit" => mit("A", "L"), "Eintrittsd" => "01.03.2015")
      expect(row.roles).to eq [
        {group: groups(:zuerich), type: Group::Sektion::Aktivmitglied,
         start_on: Date.new(2015, 3, 1), end_on: nil},
        {group: groups(:zuerich), type: Group::Sektion::Partnermitglied,
         start_on: Date.new(2015, 3, 1), end_on: nil}
      ]
    end

    it "creates one Aktivmitglied for A, R and Q together" do
      values["Code 4 Mit"] = mit("A", "Q", "R")
      expect(role_types).to eq [Group::Sektion::Aktivmitglied]
    end

    it "ends the role at Austrittsdatum" do
      values.merge!("Code 4 Mit" => "_b________________________", "Eintrittsd" => "01.01.2010",
        "Austrittsd" => "31.12.2020")
      expect(row.roles.first).to include(type: Group::Sektion::Berufsmitglied,
        start_on: Date.new(2010, 1, 1), end_on: Date.new(2020, 12, 31))
    end

    it "keeps an empty start date" do
      expect(row.roles.first).to include(start_on: nil, end_on: nil)
    end

    it "rejects every unknown code" do
      values["Code 4 Mit"] = "A___________________________YZ"
      expect(role_types).to eq [Group::Sektion::Aktivmitglied]
      expect(row.errors).to eq ["Code 4 Mit 'Y' ist unbekannt", "Code 4 Mit 'Z' ist unbekannt"]
    end

    it "rejects an invalid date only once for several roles" do
      values.merge!("Code 4 Mit" => mit("A", "L"), "Eintrittsd" => "1.13.2015")
      expect(row.errors).to eq ["Eintrittsd '1.13.2015' ist kein Datum im Format TT.MM.JJJJ"]
    end
  end

  describe "Ex-Mitglieder" do
    it "starts at Austrittsdatum without end" do
      values.merge!("Code 4 Mit" => mit("X"), "Eintrittsd" => "01.01.2000",
        "Austrittsd" => "31.12.2020")
      expect(row.roles).to eq [{group: groups(:zuerich), type: Group::Sektion::ExMitglied,
                                start_on: Date.new(2020, 12, 31), end_on: nil}]
    end

    it "falls back to Eintrittsdatum" do
      values.merge!("Code 4 Mit" => mit("X"), "Eintrittsd" => "01.01.2000")
      expect(row.roles.first).to include(start_on: Date.new(2000, 1, 1), end_on: nil)
    end

    it "ends the other roles and starts Ex Mitglied at Austrittsdatum" do
      values.merge!("Code 4 Mit" => mit("A", "X"), "Eintrittsd" => "01.01.2000",
        "Austrittsd" => "31.12.2020")
      expect(row.roles).to eq [
        {group: groups(:zuerich), type: Group::Sektion::Aktivmitglied,
         start_on: Date.new(2000, 1, 1), end_on: Date.new(2020, 12, 31)},
        {group: groups(:zuerich), type: Group::Sektion::ExMitglied,
         start_on: Date.new(2020, 12, 31), end_on: nil}
      ]
    end
  end

  describe "Sektionszuordnung" do
    it "accepts the section code with and without decimals" do
      values["Sektionszu"] = "6"
      expect(row.roles.first[:group]).to eq groups(:zuerich)
    end

    it "rejects an unknown section" do
      values["Sektionszu"] = "XY"
      expect(row.roles).to be_empty
      expect(row.errors).to eq ["Sektionszu 'XY' ist nicht zugeordnet"]
    end

    it "rejects a missing section once for several codes" do
      values.merge!("Code 4 Mit" => mit("A", "L"), "Sektionszu" => nil)
      expect(row.errors).to eq ["Sektionszu '' ist nicht zugeordnet"]
    end
  end

  describe "Interessenten und Verstorbene" do
    it "maps I to Kontakt in the interessenten group without section" do
      values.merge!("Code 4 Mit" => mit("I"), "Sektionszu" => nil)
      expect(row.roles).to eq [{group: groups(:kontakte), type: Group::DachverbandKontakte::Kontakt,
                                start_on: Time.zone.today, end_on: nil}]
      expect(row.errors).to be_empty
    end

    it "adds Kontakt next to further member roles" do
      values["Code 4 Mit"] = mit("A", "I")
      expect(role_types).to eq [Group::DachverbandKontakte::Kontakt, Group::Sektion::Aktivmitglied]
    end

    it "starts the Kontakt role today regardless of Eintritt and Austritt" do
      values.merge!("Code 4 Mit" => mit("I"), "Eintrittsd" => "01.01.2010",
        "Austrittsd" => "31.12.2020")
      expect(row.roles.first).to include(start_on: Time.zone.today, end_on: nil)
    end

    it "ignores an invalid Eintrittsdatum of an interested person" do
      values.merge!("Code 4 Mit" => mit("I"), "Eintrittsd" => "irgendwann")
      expect(row.errors).to be_empty
    end

    it "marks V as deceased" do
      values["Code 4 Mit"] = mit("V")
      expect(row).to be_deceased
    end

    it "marks V with further codes as deceased" do
      values["Code 4 Mit"] = mit("A", "V", "X")
      expect(row).to be_deceased
    end

    it "does not mark others as deceased" do
      expect(row).not_to be_deceased
    end
  end

  describe "Abo-Rolle" do
    it "adds the abo role next to the member role" do
      values.merge!("Code 3 ABo" => abo("2"), "Abo Beginn" => "01.01.2024",
        "Abo Ende" => "31.12.2024")
      expect(row.roles.last).to eq({group: groups(:abonnemente),
                                    type: Group::DachverbandAbonnemente::JahresaboMitglied,
                                    start_on: Date.new(2024, 1, 1),
                                    end_on: Date.new(2024, 12, 31)})
    end

    it "creates a role per abo code with the same dates" do
      values.merge!("Code 4 Mit" => nil, "Code 3 ABo" => "_1_____7__",
        "Abo Beginn" => "01.01.2024")
      expect(row.roles).to eq [
        {group: groups(:abonnemente), type: Group::DachverbandAbonnemente::JahresaboSchweiz,
         start_on: Date.new(2024, 1, 1), end_on: nil},
        {group: groups(:abonnemente), type: Group::DachverbandAbonnemente::Gratisabo,
         start_on: Date.new(2024, 1, 1), end_on: nil}
      ]
    end

    it "maps an abo without membership and ignores Sektionszu" do
      values.merge!("Code 4 Mit" => mit, "Sektionszu" => "XY", "Code 3 ABo" => abo("1"))
      expect(role_types).to eq [Group::DachverbandAbonnemente::JahresaboSchweiz]
      expect(row.errors).to be_empty
    end

    it "maps every abo code" do
      mapping = FloristImport::Mappings::ABO_ROLES
      types = mapping.keys.map do |code|
        build_row(base_values.merge("Code 3 ABo" => abo(code))).roles.last[:type]
      end
      expect(types).to eq mapping.values
    end

    it "ignores abo code 4 with a note" do
      values["Code 3 ABo"] = abo("4")
      expect(role_types).to eq [Group::Sektion::Aktivmitglied]
      expect(row.notes).to eq ["Abo-Code 4 (Jahresabo Jungfloristen) nicht importiert"]
      expect(row.errors).to be_empty
    end

    it "rejects an unknown abo code" do
      values["Code 3 ABo"] = abo("0")
      expect(row.errors).to eq ["Code 3 ABo '0' ist unbekannt"]
    end
  end

  describe "Mindestens eine Rolle" do
    it "rejects a row without codes" do
      values["Code 4 Mit"] = nil
      expect(row.errors).to eq [no_role_error]
    end

    it "rejects a row with only abo code 4" do
      values.merge!("Code 4 Mit" => nil, "Code 3 ABo" => abo("4"))
      expect(row.errors).to eq [no_role_error]
    end
  end

  describe "Qualifikationen" do
    it "lists the set columns" do
      values.merge!("SKBEQ" => "x", "Kursleiterin" => "Ja", "QV-Expertin" => "0",
        "BP-Expertin" => "nein", "üK-Expertin" => "False", "Berufsfachschule" => " ")
      expect(row.qualification_labels).to eq %w[SKBEQ Kursleiterin]
    end
  end

  it "returns the original line" do
    expect(row.raw).to start_with "4711,,,Muster,Erika,,A_________________________,"
  end
end
