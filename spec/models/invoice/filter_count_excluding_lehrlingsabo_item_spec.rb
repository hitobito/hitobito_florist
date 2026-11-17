# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"

describe Invoice::FilterCountExcludingLehrlingsaboItem do
  let(:aargau) { groups(:aargau) }
  let(:abonnemente) { groups(:abonnemente) }

  let(:period_start_on) { Date.new(2026, 1, 1) }
  let(:period_end_on) { Date.new(2026, 12, 31) }
  let(:only_exclude_first_year_lehrlingsabos) { false }

  let(:attrs) do
    {
      invoice: Fabricate(:invoice, group: groups(:root)),
      name: "Grundtaxe",
      dynamic_cost_parameters: {
        unit_cost: 50,
        period_start_on: period_start_on,
        period_end_on: period_end_on,
        relevant_role_types: [Group::Sektion::Berufsmitgliedplus.sti_name],
        only_exclude_first_year_lehrlingsabos: only_exclude_first_year_lehrlingsabos
      }
    }
  end

  subject(:item) { described_class.for_people(Person.all, **attrs) }

  def berufsmitgliedplus
    Fabricate(:person).tap do |person|
      Fabricate(Group::Sektion::Berufsmitgliedplus.sti_name, group: aargau, person: person,
        start_on: period_start_on - 2.years, end_on: period_end_on + 1.year)
    end
  end

  def lehrlingsabo(person, start_on:, end_on: nil)
    Fabricate(Group::DachverbandAbonnemente::Lehrlingsabo.sti_name, group: abonnemente,
      person: person, start_on: start_on, end_on: end_on)
  end

  it "counts members without Lehrlingsabo" do
    berufsmitgliedplus
    expect(item.count).to eq 1
  end

  it "ignores members with a Lehrlingsabo started in an earlier year" do
    lehrlingsabo(berufsmitgliedplus, start_on: Date.new(2024, 8, 1))
    expect(item.count).to eq 0
  end

  it "ignores members with a Lehrlingsabo started in the year the period ends" do
    lehrlingsabo(berufsmitgliedplus, start_on: Date.new(2026, 8, 1))
    expect(item.count).to eq 0
  end

  it "ignores members with a Lehrlingsabo ending during the period" do
    lehrlingsabo(berufsmitgliedplus, start_on: Date.new(2024, 8, 1), end_on: Date.new(2026, 7, 31))
    expect(item.count).to eq 0
  end

  it "counts members whose Lehrlingsabo ended before the period" do
    lehrlingsabo(berufsmitgliedplus, start_on: Date.new(2022, 8, 1), end_on: Date.new(2025, 7, 31))
    expect(item.count).to eq 1
  end

  it "counts members whose Lehrlingsabo starts after the period" do
    lehrlingsabo(berufsmitgliedplus, start_on: Date.new(2027, 1, 1))
    expect(item.count).to eq 1
  end

  it "lists only members without Lehrlingsabo as subjects" do
    person = berufsmitgliedplus
    lehrlingsabo(berufsmitgliedplus, start_on: Date.new(2024, 8, 1))
    expect(item.subjects.pluck(:subject_id)).to eq [person.id]
  end

  context "only excluding first year Lehrlingsabos" do
    let(:only_exclude_first_year_lehrlingsabos) { true }

    it "ignores members with a Lehrlingsabo started in the year the period ends" do
      lehrlingsabo(berufsmitgliedplus, start_on: Date.new(2026, 8, 1))
      expect(item.count).to eq 0
    end

    it "ignores members with a Lehrlingsabo started in the year before the period ends" do
      lehrlingsabo(berufsmitgliedplus, start_on: Date.new(2025, 1, 1))
      expect(item.count).to eq 0
    end

    it "counts members with a Lehrlingsabo started two years before the period ends" do
      lehrlingsabo(berufsmitgliedplus, start_on: Date.new(2024, 12, 31))
      expect(item.count).to eq 1
    end

    it "uses the calendar year of a period end given as string" do
      attrs[:dynamic_cost_parameters][:period_end_on] = "2026-12-31"
      lehrlingsabo(berufsmitgliedplus, start_on: Date.new(2025, 1, 1))
      expect(item.count).to eq 0
    end
  end
end
