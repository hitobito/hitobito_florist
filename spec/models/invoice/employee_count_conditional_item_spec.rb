# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"

describe Invoice::EmployeeCountConditionalItem do
  let(:root) { groups(:root) }
  let(:aargau) { groups(:aargau) }

  let(:period_start_on) { Date.new(2026, 1, 1) }
  let(:period_end_on) { Date.new(2026, 12, 31) }

  let(:invoice) { Fabricate(:invoice, group: root) }

  let(:attrs) do
    {
      invoice: invoice,
      name: "Grundtaxe bis 2 Mitarbeiter",
      dynamic_cost_parameters: {
        unit_cost: 440,
        period_start_on: period_start_on,
        period_end_on: period_end_on,
        relevant_role_types: [Group::Sektion::Aktivmitglied.sti_name],
        min_employees: 2,
        max_employees: 2
      }
    }
  end

  subject(:item) { described_class.for_people(Person.all, **attrs) }

  def member(full_time, part_time)
    person = Fabricate(:person, full_time_employees: full_time, part_time_employees: part_time)
    Fabricate(Group::Sektion::Aktivmitglied.sti_name, group: aargau, person: person,
      start_on: period_start_on - 1.year, end_on: period_end_on + 1.year)
    person
  end

  it "is invalid without a lower bound" do
    member(1, 1)
    item.dynamic_cost_parameters[:min_employees] = nil
    expect(item).not_to be_valid
  end

  describe "#count" do
    it "counts full time and part time employees together" do
      member(1, 1)
      member(2, 0)
      member(0, 2)
      expect(item.count).to eq 3
    end

    it "ignores businesses below the lower bound" do
      member(1, 0)
      member(0, 0)
      expect(item.count).to eq 0
    end

    it "ignores businesses above the upper bound" do
      member(2, 1)
      member(10, 10)
      expect(item.count).to eq 0
    end

    context "without an upper bound" do
      before { attrs[:dynamic_cost_parameters][:max_employees] = nil }

      it "counts every business with at least the lower bound" do
        member(1, 1)
        member(10, 10)
        member(1, 0)
        expect(item.count).to eq 2
      end
    end

    context "with a lower bound of zero" do
      before do
        attrs[:dynamic_cost_parameters][:min_employees] = 0
        attrs[:dynamic_cost_parameters][:max_employees] = 1
      end

      it "counts businesses without any employee" do
        member(0, 0)
        member(1, 0)
        member(1, 1)
        expect(item.count).to eq 2
      end
    end
  end

  describe "#dynamic_cost" do
    it "multiplies unit cost and count" do
      member(2, 0)
      expect(item.dynamic_cost).to eq 440
    end
  end
end
