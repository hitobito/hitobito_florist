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
    instance_double(FloristImport::CheckedRow, id: 1011, address_number: "1011",
      first_name: "Anna", last_name: "Abo", hints: [])
  end

  subject(:report) { described_class.new }

  after { FileUtils.rm_rf(dir) }

  def written_rows
    report.write(path)
    CSV.read(path, encoding: "UTF-8").drop(1)
  end

  it "writes the header row" do
    report.write(path)
    expect(File.read(path)).to eq "Adressnumm,Status,Vorname,Nachname,Meldungen\n"
  end

  it "writes a rejected row with a cell per error" do
    report.rejected(row, ["Code 3 Abo '0' ist unbekannt", "Telefonnummer ist nicht gültig"])
    expect(written_rows).to eq [["1011", "ABGELEHNT", "Anna", "Abo",
      "Code 3 Abo '0' ist unbekannt", "Telefonnummer ist nicht gültig"]]
    expect(report.counts).to eq(rejected: 1)
  end

  it "writes a skipped row" do
    report.skipped(row, "Verstorben (Code 4 Mit 'V')")
    expect(written_rows).to eq [["1011", "ÜBERSPRUNGEN", "Anna", "Abo",
      "Verstorben (Code 4 Mit 'V')"]]
    expect(report.counts).to eq(skipped: 1)
  end

  it "counts an imported row without hints but does not write it" do
    report.imported(row, replaced: false)
    expect(written_rows).to be_empty
    expect(report.counts).to eq(imported: 1)
  end

  it "writes the hints of an imported row" do
    allow(row).to receive(:hints).and_return(["Kanton 'xx' ist ungültig"])
    report.imported(row, replaced: false)
    expect(written_rows).to eq [["1011", "HINWEIS", "Anna", "Abo", "Kanton 'xx' ist ungültig"]]
    expect(report.counts).to eq(imported: 1, with_notes: 1)
  end

  it "notes a replaced person first" do
    allow(row).to receive(:hints).and_return(["Kanton 'xx' ist ungültig"])
    report.imported(row, replaced: true)
    expect(written_rows).to eq [["1011", "HINWEIS", "Anna", "Abo",
      "Bestehende Person 1011 ersetzt", "Kanton 'xx' ist ungültig"]]
    expect(report.counts).to eq(imported: 1, replaced: 1, with_notes: 1)
  end

  it "counts the total" do
    2.times { report.total! }
    expect(report.counts[:total]).to eq 2
  end
end
