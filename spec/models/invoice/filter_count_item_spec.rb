# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"

describe Invoice::FilterCountItem do
  let(:root) { groups(:root) }
  let(:aargau) { groups(:aargau) }
  let(:zuerich) { groups(:zuerich) }
  let(:nordwestschweiz) { groups(:nordwestschweiz) }

  let(:period_start_on) { Date.new(2026, 1, 1) }
  let(:period_end_on) { Date.new(2026, 12, 31) }

  let(:invoice) { Fabricate(:invoice, group: root) }
  let(:recipient_people) { Person.all }

  let(:attrs) do
    {
      invoice: invoice,
      name: "Grundtaxe",
      dynamic_cost_parameters: {
        unit_cost: 50,
        period_start_on: period_start_on,
        period_end_on: period_end_on,
        relevant_role_types: [Group::Sektion::Aktivmitglied.sti_name]
      }
    }
  end

  subject(:item) { described_class.for_people(recipient_people, **attrs) }

  def member(group, role = Group::Sektion::Aktivmitglied, **person_attrs)
    person = Fabricate(:person, **person_attrs)
    Fabricate(role.sti_name, group: group, person: person,
      start_on: period_start_on - 1.year, end_on: period_end_on + 1.year)
    person
  end

  describe "validation" do
    before { member(aargau) }

    it "is valid" do
      expect(item).to be_valid
    end

    it "is invalid without relevant role types" do
      item.dynamic_cost_parameters[:relevant_role_types] = nil
      expect(item).not_to be_valid
    end

    it "is invalid without period start" do
      item.dynamic_cost_parameters[:period_start_on] = nil
      expect(item).not_to be_valid
    end

    it "is invalid if it applies to nobody, so that it is dropped from the invoice" do
      expect(described_class.for_people(Person.none, **attrs)).not_to be_valid
    end
  end

  describe "#count" do
    it "is 0 without any matching role" do
      member(aargau, Group::Sektion::Passivmitglied)
      expect(item.count).to eq 0
    end

    it "counts the members of all sections" do
      member(aargau)
      member(aargau)
      member(zuerich)
      expect(item.count).to eq 3
    end

    it "counts a member of two sections only once for the umbrella organisation" do
      person = member(aargau)
      Fabricate(Group::Sektion::Aktivmitglied.sti_name, group: zuerich, person: person,
        start_on: period_start_on - 1.year, end_on: period_end_on + 1.year)
      expect(item.count).to eq 1
    end

    it "ignores sections which invoice their members themselves" do
      member(nordwestschweiz)
      member(aargau)
      expect(item.count).to eq 1
    end

    it "ignores people who are not among the recipients" do
      member(aargau)
      other = member(zuerich)
      expect(described_class.for_people(Person.where.not(id: other), **attrs).count).to eq 1
    end

    it "ignores a role starting after the beginning of the period" do
      person = Fabricate(:person)
      Fabricate(Group::Sektion::Aktivmitglied.sti_name, group: aargau, person: person,
        start_on: period_start_on + 1.day, end_on: period_end_on + 1.year)
      expect(item.count).to eq 0
    end

    it "ignores a role ending before the end of the period" do
      person = Fabricate(:person)
      Fabricate(Group::Sektion::Aktivmitglied.sti_name, group: aargau, person: person,
        start_on: period_start_on - 1.year, end_on: period_end_on - 1.day)
      expect(item.count).to eq 0
    end

    context "with a condition on the person" do
      before do
        attrs[:dynamic_cost_parameters][:where] = {people: {visited_gv_dachverband: true}}
      end

      it "only counts the people matching the condition" do
        member(aargau, visited_gv_dachverband: true)
        member(aargau, visited_gv_dachverband: false)
        expect(item.count).to eq 1
      end
    end

    context "restricted to one section" do
      before { attrs[:dynamic_cost_parameters][:section_id] = aargau.id }

      it "only counts the members of that section" do
        member(aargau)
        member(zuerich)
        expect(item.count).to eq 1
      end

      it "counts a member of two sections once per section" do
        person = member(aargau)
        Fabricate(Group::Sektion::Aktivmitglied.sti_name, group: zuerich, person: person,
          start_on: period_start_on - 1.year, end_on: period_end_on + 1.year)
        expect(item.count).to eq 1
      end
    end
  end

  describe "#dynamic_cost" do
    it "multiplies unit cost and count" do
      2.times { member(aargau) }
      expect(item.dynamic_cost).to eq 100
    end
  end

  describe "#subjects" do
    it "lists the counted people, so that a later run does not charge them again" do
      person = member(aargau)
      expect(item.subjects).to eq [
        {subject_id: person.id, subject_type: "Person", template_item_id: nil, item_id: nil}
      ]
    end
  end
end
