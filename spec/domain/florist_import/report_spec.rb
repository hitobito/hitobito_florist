# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"

describe FloristImport::Report do
  let(:dir) { Pathname(Dir.mktmpdir) }
  let(:path) { dir.join("report.csv") }
  let(:row) do
    instance_double(FloristImport::Row, address_number: "1011", first_name: "Anna",
      last_name: "Abo")
  end

  subject(:report) { described_class.new }

  after { FileUtils.rm_rf(dir) }

  it "writes the header row" do
    report.write(path)
    expect(File.read(path)).to eq "Adressnumm,Status,Vorname,Nachname,Meldungen\n"
  end

  it "writes one row per entry with a cell per message" do
    report.add(row, "ABGELEHNT", ["Code 3 Abo '0' ist unbekannt", "Telefonnummer ist nicht gültig"])
    report.add(row, "HINWEIS", ["Kanton 'xx' ist ungültig"])
    report.write(path)
    expect(CSV.read(path, encoding: "UTF-8").drop(1)).to eq [
      ["1011", "ABGELEHNT", "Anna", "Abo", "Code 3 Abo '0' ist unbekannt",
        "Telefonnummer ist nicht gültig"],
      ["1011", "HINWEIS", "Anna", "Abo", "Kanton 'xx' ist ungültig"]
    ]
  end
end
