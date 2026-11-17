# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"

describe FloristImport::Progress do
  let(:io) { StringIO.new }
  let(:now) { [0.0] }
  let(:counts) { {imported: 1100, rejected: 80, skipped: 20} }

  subject(:progress) { described_class.new(io, clock: -> { now.first }) }

  def at(seconds) = now.replace([seconds])

  describe "without terminal" do
    it "prints one line per 10 percent" do
      progress.start(5000)
      (1..5000).each { |processed| progress.step(processed, counts) }
      lines = io.string.lines
      expect(lines.size).to eq 10
      expect(lines.first).to start_with "Zeilen 500/5000 (10%)"
      expect(lines.last).to start_with "Zeilen 5000/5000 (100%)"
    end

    it "prints a line per row for less than 10 rows" do
      progress.start(3)
      (1..3).each { |processed| progress.step(processed, counts) }
      expect(io.string.lines.size).to eq 3
    end

    it "prints the counts and the remaining time" do
      progress.start(5000)
      at(120.0)
      progress.step(1200, counts)
      expect(io.string).to eq "Zeilen 1200/5000 (24%) | importiert 1100 | abgelehnt 80 | " \
        "übersprungen 20 | Restdauer ca. 6 Min.\n"
    end
  end

  describe "in a terminal" do
    before { allow(io).to receive(:tty?).and_return(true) }

    it "overwrites a single line" do
      progress.start(5000)
      at(1.0)
      progress.step(1, counts)
      expect(io.string).to start_with "\r\e[KZeilen 1/5000 (0%) | importiert 1100"
      expect(io.string).not_to include "\n"
    end

    it "updates at most every half second and always at the end" do
      progress.start(3)
      at(0.1)
      progress.step(1, counts)
      at(0.2)
      progress.step(2, counts)
      at(0.3)
      progress.step(3, counts)
      expect(io.string.scan("\r").size).to eq 2
      expect(io.string).to include "Zeilen 3/3 (100%)"
    end

    it "ends the line before a phase and on finish" do
      progress.start(2)
      progress.step(1, counts)
      progress.phase("Weiter …")
      progress.step(2, counts)
      progress.finish
      expect(io.string).to end_with "\n"
      expect(io.string).to include "\nWeiter …\n"
    end
  end

  describe "remaining time" do
    before { progress.start(100) }

    it "is unknown before the first row" do
      progress.step(0, counts)
      expect(io.string).to be_empty
      expect(progress.send(:remaining, 0)).to eq "Restdauer unbekannt"
    end

    it "is given in seconds below a minute" do
      at(10.0)
      expect(progress.send(:remaining, 50)).to eq "Restdauer ca. 10 Sek."
    end

    it "is given in minutes from a minute on" do
      at(100.0)
      expect(progress.send(:remaining, 10)).to eq "Restdauer ca. 15 Min."
    end
  end

  it "prints phases on their own line" do
    progress.phase("Datei wird gelesen …")
    expect(io.string).to eq "Datei wird gelesen …\n"
  end
end
