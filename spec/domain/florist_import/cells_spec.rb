# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"

describe FloristImport::Cells do
  let(:headers) { ["Zahl", "Datum", "Codes", "Funktion"] }
  let(:values) { {} }

  subject(:cells) { described_class.new(CSV::Row.new(headers, headers.map { |h| values[h] })) }

  describe "#value" do
    it "strips and reads blank values as nil" do
      values.merge!("Zahl" => " 7 ", "Datum" => " ")
      expect([cells.value("Zahl"), cells.value("Datum")]).to eq ["7", nil]
    end

    it "fails on a column missing in the headers" do
      expect { cells.value("Zal") }.to raise_error(KeyError, /Zal/)
    end
  end

  describe "#integer" do
    it "reads integral decimals" do
      values["Zahl"] = "4.0"
      expect(cells.integer("Zahl")).to eq 4
    end

    it "reads an empty optional value as 0" do
      expect(cells.integer("Zahl")).to eq 0
      expect(cells.errors).to be_empty
    end

    it "reports a missing required value" do
      expect(cells.integer("Zahl", required: true)).to be_nil
      expect(cells.errors).to eq ["Zahl fehlt"]
    end

    it "reports a non numeric value" do
      values["Zahl"] = "4.5"
      expect(cells.integer("Zahl")).to eq 0
      expect(cells.errors).to eq ["Zahl '4.5' ist keine ganze Zahl"]
    end
  end

  it "normalizes integer codes" do
    values["Zahl"] = "6.0"
    expect(cells.integer_code("Zahl")).to eq "6"
  end

  describe "#date" do
    it "reads the export format" do
      values["Datum"] = "2024-03-15"
      expect(cells.date("Datum")).to eq Date.new(2024, 3, 15)
    end

    it "reports another format once" do
      values["Datum"] = "15.03.2024"
      2.times { expect(cells.date("Datum")).to be_nil }
      expect(cells.errors).to eq ["Datum '15.03.2024' ist kein Datum im Format JJJJ-MM-TT"]
    end
  end

  it "reads every character except _ as code" do
    values["Codes"] = "a_X_a"
    expect(cells.codes("Codes")).to eq %w[A X]
  end

  it "treats 0, nein and false as unset" do
    set = %w[0 nein False x].map do |value|
      described_class.new(CSV::Row.new(["Funktion"], [value])).set?("Funktion")
    end
    expect(set).to eq [false, false, false, true]
  end

  it "appends to the given errors" do
    errors = ["vorher"]
    described_class.new(CSV::Row.new(["Zahl"], [nil]), errors:).integer("Zahl", required: true)
    expect(errors).to eq ["vorher", "Zahl fehlt"]
  end
end
