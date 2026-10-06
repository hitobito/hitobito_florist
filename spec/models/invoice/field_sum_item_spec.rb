# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"

describe Invoice::FieldSumItem do
  let(:root) { groups(:root) }
  let(:aargau) { groups(:aargau) }
  let(:zuerich) { groups(:zuerich) }

  let(:period_start_on) { Date.new(2026, 1, 1) }
  let(:period_end_on) { Date.new(2026, 12, 31) }

  let(:invoice) { Fabricate(:invoice, group: root) }

  let(:attrs) do
    {
      invoice: invoice,
      name: "Beitrag pro Vollzeitangestellte",
      dynamic_cost_parameters: {
        unit_cost: 130,
        period_start_on: period_start_on,
        period_end_on: period_end_on,
        relevant_role_types: [Group::Sektion::Aktivmitglied.sti_name],
        field: "full_time_employees"
      }
    }
  end

  subject(:item) { described_class.for_people(Person.all, **attrs) }

  def member(group, **person_attrs)
    person = Fabricate(:person, **person_attrs)
    Fabricate(Group::Sektion::Aktivmitglied.sti_name, group: group, person: person,
      start_on: period_start_on - 1.year, end_on: period_end_on + 1.year)
    person
  end

  describe "validation" do
    before { member(aargau, full_time_employees: 2) }

    it "is valid" do
      expect(item).to be_valid
    end
  end

  describe "#count" do
    it "sums the field over all counted people" do
      member(aargau, full_time_employees: 2)
      member(zuerich, full_time_employees: 3)
      expect(item.count).to eq 5
    end

    it "is 0 without any counted person" do
      member(aargau, full_time_employees: 2, part_time_employees: 5)
      attrs[:dynamic_cost_parameters][:relevant_role_types] =
        [Group::Sektion::Passivmitglied.sti_name]
      expect(item.count).to eq 0
    end

    it "sums a member of two sections only once for the umbrella organisation" do
      person = member(aargau, full_time_employees: 4)
      Fabricate(Group::Sektion::Aktivmitglied.sti_name, group: zuerich, person: person,
        start_on: period_start_on - 1.year, end_on: period_end_on + 1.year)
      expect(item.count).to eq 4
    end

    it "sums another field when configured" do
      attrs[:dynamic_cost_parameters][:field] = "branches"
      member(aargau, full_time_employees: 2, branches: 3)
      expect(item.count).to eq 3
    end

    context "restricted to one section" do
      before { attrs[:dynamic_cost_parameters][:section_id] = aargau.id }

      it "sums a member of two sections once for that section" do
        person = member(aargau, full_time_employees: 4)
        Fabricate(Group::Sektion::Aktivmitglied.sti_name, group: zuerich, person: person,
          start_on: period_start_on - 1.year, end_on: period_end_on + 1.year)
        member(zuerich, full_time_employees: 7)
        expect(item.count).to eq 4
      end
    end
  end

  describe "#dynamic_cost" do
    it "multiplies unit cost and summed field" do
      member(aargau, full_time_employees: 2)
      expect(item.dynamic_cost).to eq 260
    end

    it "is negative for a credit" do
      attrs[:dynamic_cost_parameters][:unit_cost] = -60
      attrs[:dynamic_cost_parameters][:field] = "apprentices"
      member(aargau, apprentices: 2)
      expect(item.dynamic_cost).to eq(-120)
    end
  end
end
