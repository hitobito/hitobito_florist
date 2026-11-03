# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"

describe FloristImport::CheckedRow, :with_truemail_validation do
  let(:headers) { FloristImport::Mappings::REQUIRED_HEADERS }
  let(:values) { {} }
  let(:email_taken) { false }
  let(:data) do
    {"Adressnumm" => "4711", "Name" => "Muster", "Land" => "CH",
     "Telefon Ge" => "+41 44 668 18 01", "Mobilnumme" => "+41 79 123 45 67",
     "Telefon Pr" => "+41 44 668 18 00", "Email-Adre" => "erika@example.com",
     "E-Mail RG" => "rechnung@example.com", "Zusatz Ema" => "privat@example.com"}.merge(values)
  end
  let(:row) do
    FloristImport::Row.new(CSV::Row.new(headers, headers.map { |h| data[h] }), line: 2)
  end

  subject(:check) { described_class.new(row, email_taken:) }

  around do |example|
    previous = Truemail.configuration.default_validation_type
    Truemail.configuration.default_validation_type = :regex
    example.run
  ensure
    Truemail.configuration.default_validation_type = previous
  end

  it "keeps valid contact data unchanged" do
    expect(check.attributes).to eq row.attributes
    expect(check.attributes["phone_number_private"]).to eq "+41 44 668 18 00"
    expect(check.person_notes).to be_empty
    expect(check.hints).to be_empty
    expect(check.attributes).not_to have_key("tags")
  end

  describe "Telefonnummern" do
    it "drops an invalid mobile number" do
      values["Mobilnumme"] = "abc"
      expect(check.attributes).not_to have_key("phone_number_mobile")
      expect(check.attributes["phone_number_business"]).to eq "+41 44 668 18 01"
      expect(check.attributes["tags"]).to eq "Datenmigration:Telefonnummer ungültig"
      expect(check.person_notes).to eq ["Ungültige Telefonnummer Mobil: abc"]
      expect(check.hints).to eq ["Mobilnumme 'abc' ist ungültig und wurde nicht übernommen"]
    end

    it "names the phone field in the notes" do
      values.merge!("Telefon Ge" => "123", "Telefon Pr" => "xyz")
      expect(check.attributes).not_to have_key("phone_number_private")
      expect(check.person_notes).to eq ["Ungültige Telefonnummer Geschäft: 123",
        "Ungültige Telefonnummer Privat: xyz"]
      expect(check.attributes["tags"]).to eq "Datenmigration:Telefonnummer ungültig"
    end
  end

  describe "E-Mails" do
    it "drops an invalid main email" do
      values["Email-Adre"] = "info@@blumen"
      expect(check.attributes).not_to have_key("email")
      expect(check.person_notes).to eq ["Ungültige Email: info@@blumen"]
      expect(check.attributes["tags"]).to eq "Datenmigration:E-Mail ungültig"
    end

    it "drops an invalid invoice email" do
      values["E-Mail RG"] = "rechnung@@blumen"
      expect(check.attributes).not_to have_key("additional_email_invoices")
      expect(check.attributes["tags"]).to eq "Datenmigration:E-Mail ungültig"
      expect(check.person_notes).to eq ["Ungültige E-Mail RG: rechnung@@blumen"]
    end

    it "drops an invalid additional email" do
      values["Zusatz Ema"] = "privat@@blumen"
      expect(check.attributes).not_to have_key("additional_email_private")
      expect(check.person_notes).to eq ["Ungültige Zusatz Email: privat@@blumen"]
    end

    context "already taken" do
      let(:email_taken) { true }

      it "moves the main email to the duplicate" do
        expect(check.attributes).not_to have_key("email")
        expect(check.duplicate_email).to eq "erika@example.com"
        expect(check.person_notes).to be_empty
        expect(check.attributes).not_to have_key("tags")
        expect(check.hints).to eq ["Email-Adre erika@example.com ist bereits vergeben und wurde " \
          "als zusätzliche E-Mail \"Duplikat\" übernommen"]
      end

      it "treats an invalid taken email as invalid only" do
        values["Email-Adre"] = "info@@blumen"
        expect(check.duplicate_email).to be_nil
        expect(check.person_notes).to eq ["Ungültige Email: info@@blumen"]
      end
    end
  end

  it "tags each invalid contact type once and notes every invalid value" do
    values.merge!("Mobilnumme" => "abc", "Email-Adre" => "info@@blumen")
    expect(check.attributes["tags"])
      .to eq "Datenmigration:Telefonnummer ungültig, Datenmigration:E-Mail ungültig"
    expect(check.person_notes).to eq ["Ungültige Telefonnummer Mobil: abc",
      "Ungültige Email: info@@blumen"]
    expect(check.hints.size).to eq 2
  end

  describe "PLZ" do
    it "drops an invalid Swiss zip code" do
      values["Postleitza"] = "80011"
      expect(check.attributes).not_to have_key("zip_code")
      expect(check.attributes["tags"]).to eq "Datenmigration:PLZ ungültig"
      expect(check.person_notes).to eq ["Ungültige PLZ: 80011"]
      expect(check.hints).to eq ["Postleitza '80011' ist ungültig und wurde nicht übernommen"]
    end

    it "keeps a valid zip code" do
      values["Postleitza"] = "8001"
      expect(check.attributes["zip_code"]).to eq "8001"
      expect(check.attributes).not_to have_key("tags")
    end

    it "validates the zip code for the country" do
      values.merge!("Land" => "DE", "Postleitza" => "10117")
      expect(check.attributes["zip_code"]).to eq "10117"
    end
  end

  it "adds the hints and the mutation note of the row" do
    values.merge!("Code 3 Abo" => "____4_____", "Mutationsd" => "2024-03-15",
      "Mobilnumme" => "abc")
    expect(check.hints).to eq ["Abo-Code 4 (Jahresabo Jungfloristen) nicht importiert",
      "Mobilnumme 'abc' ist ungültig und wurde nicht übernommen"]
    expect(check.person_notes)
      .to eq ["Mutationsdatum: 2024-03-15", "Ungültige Telefonnummer Mobil: abc"]
  end

  it "tags invalid data only for invalid contact fields" do
    values["Mutationsd"] = "2024-03-15"
    expect(check.attributes).not_to have_key("tags")
  end

  it "delegates the row values" do
    expect([check.id, check.address_number, check.errors]).to eq [4711, "4711", []]
  end

  it "combines the tags of the row and the checks" do
    values.merge!("Mobilnumme" => "abc", "Postleitza" => "80011")
    allow(row).to receive(:tags).and_return(["Datenmigration:Sektion fehlt"])
    expect(check.attributes["tags"].split(", ")).to eq ["Datenmigration:Sektion fehlt",
      "Datenmigration:Telefonnummer ungültig", "Datenmigration:PLZ ungültig"]
  end

  describe "Kanton" do
    it "keeps a valid canton" do
      values["Kanton"] = "ZH"
      expect(check.attributes["canton"]).to eq "zh"
      expect(check.hints).to be_empty
    end

    it "drops an invalid canton in Switzerland" do
      values["Kanton"] = "XX"
      expect(check.attributes).not_to have_key("canton")
      expect(check.hints).to eq ["Kanton 'xx' ist ungültig und wurde nicht übernommen"]
      expect(check.person_notes).to be_empty
    end

    it "checks the canton without country" do
      values.merge!("Land" => nil, "Kanton" => "XX")
      expect(check.attributes).not_to have_key("canton")
    end

    it "does not check the canton outside of Switzerland" do
      values.merge!("Land" => "DE", "Kanton" => "XX")
      expect(check.hints).to be_empty
    end
  end
end
