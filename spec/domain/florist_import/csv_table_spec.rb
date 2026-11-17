# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"

describe FloristImport::CsvTable do
  let(:dir) { Pathname(Dir.mktmpdir) }
  let(:headers) { FloristImport::Mappings::REQUIRED_HEADERS }

  after { FileUtils.rm_rf(dir) }

  def load(header_line, line = nil)
    path = dir.join("export.csv")
    path.write([header_line, line].compact.join("\n") + "\n")
    described_class.load(path)
  end

  it "reads the rows with the expected headers" do
    table = load(headers.join(","), "4711")
    expect(table.headers).to eq headers
    expect(table.first["Adressnumm"]).to eq "4711"
  end

  it "matches headers regardless of case" do
    table = load(headers.map { |h| (h == "Code 3 Abo") ? "Code 3 ABo" : h }.join(","))
    expect(table.headers).to include "Code 3 Abo"
    expect(table.headers).not_to include "Code 3 ABo"
  end

  it "keeps unknown headers" do
    expect(load((headers + ["TextBox"]).join(",")).headers.last).to eq "TextBox"
  end

  it "fails on columns differing only in case" do
    expect { load((headers + ["CODE 3 ABO"]).join(",")) }
      .to raise_error(FloristImport::Error, "Spalten mehrfach vorhanden: Code 3 Abo, CODE 3 ABO")
  end

  it "fails on missing columns" do
    expect { load((headers - ["Kanton", "Sektionszu"]).join(",")) }
      .to raise_error(FloristImport::Error, "Fehlende Spalten: Kanton, Sektionszu")
  end

  it "fails on a missing file" do
    expect { described_class.load(dir.join("missing.csv")) }
      .to raise_error(FloristImport::Error, /No such file/)
  end
end
