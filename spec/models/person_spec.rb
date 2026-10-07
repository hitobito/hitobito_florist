# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"

describe Person do
  let(:person) { people(:member) }

  describe "membership fee relevant attributes" do
    Florist::Person::COUNT_ATTRS.each do |attr|
      it "#{attr} defaults to 0" do
        expect(Person.new.send(attr)).to eq 0
      end

      it "#{attr} may be zero or positive" do
        person.send(:"#{attr}=", 3)
        expect(person).to be_valid
      end

      it "#{attr} may not be negative" do
        person.send(:"#{attr}=", -1)
        expect(person).not_to be_valid
        expect(person.errors[attr]).to be_present
      end

      it "#{attr} falls back to 0 when the form field was emptied" do
        person.send(:"#{attr}=", nil)
        expect(person).to be_valid
        expect(person.send(attr)).to eq 0
      end
    end

    it "visited_gv_dachverband defaults to false" do
      expect(Person.new.visited_gv_dachverband).to eq false
    end

    it "visited_gv_sektion defaults to false" do
      expect(Person.new.visited_gv_sektion).to eq false
    end
  end

  describe "logging" do
    with_versioning do
      it "records changes of the membership fee relevant attributes" do
        expect do
          person.update!(full_time_employees: 4, visited_gv_sektion: true)
        end.to change { person.versions.count }.by(1)

        expect(person.versions.last.object_changes)
          .to include("full_time_employees", "visited_gv_sektion")
      end
    end
  end
end
