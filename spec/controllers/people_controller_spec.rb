# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"

describe PeopleController do
  render_views

  let(:aargau) { groups(:aargau) }
  let(:member) { Fabricate(Group::Sektion::Aktivmitglied.sti_name, group: aargau).person }

  def update_person(attrs)
    put :update, params: {group_id: aargau.id, id: member.id, person: attrs}
  end

  context "as the member herself" do
    before { sign_in(member) }

    it "shows the employee counts and gv visit flags" do
      member.update!(full_time_employees: 3, visited_gv_sektion: true)
      get :show, params: {group_id: aargau.id, id: member.id}

      expect(response.body).to include("Anzahl Vollzeitangestellte")
      expect(response.body).to include("GV Besuch Sektion")
    end

    it "offers the employee counts but not the gv visit flags for editing" do
      get :edit, params: {group_id: aargau.id, id: member.id}

      expect(response.body).to include("person[full_time_employees]")
      expect(response.body).not_to include("person[visited_gv_dachverband]")
      expect(response.body).not_to include("person[visited_gv_sektion]")
    end

    it "may update the employee counts" do
      update_person(full_time_employees: 3, part_time_employees: 2, apprentices: 1, branches: 4)

      expect(member.reload.full_time_employees).to eq 3
      expect(member.part_time_employees).to eq 2
      expect(member.apprentices).to eq 1
      expect(member.branches).to eq 4
    end

    it "may not update the gv visit flags" do
      update_person(visited_gv_dachverband: true, visited_gv_sektion: true)

      expect(member.reload.visited_gv_dachverband).to eq false
      expect(member.visited_gv_sektion).to eq false
    end
  end

  context "as a Sektion role" do
    before { sign_in(Fabricate(Group::Sektion::Sektion.sti_name, group: aargau).person) }

    it "offers the section gv visit flag for editing" do
      get :edit, params: {group_id: aargau.id, id: member.id}

      expect(response.body).to include("person[visited_gv_sektion]")
      expect(response.body).not_to include("person[visited_gv_dachverband]")
    end

    it "may update the section gv visit flag only" do
      update_person(visited_gv_dachverband: true, visited_gv_sektion: true)

      expect(member.reload.visited_gv_sektion).to eq true
      expect(member.visited_gv_dachverband).to eq false
    end
  end

  context "as a Dachverband employee" do
    before { sign_in(people(:member)) }

    it "offers both gv visit flags for editing" do
      get :edit, params: {group_id: aargau.id, id: member.id}

      expect(response.body).to include("person[visited_gv_dachverband]")
      expect(response.body).to include("person[visited_gv_sektion]")
    end

    it "may update both gv visit flags" do
      update_person(visited_gv_dachverband: true, visited_gv_sektion: true)

      expect(member.reload.visited_gv_dachverband).to eq true
      expect(member.visited_gv_sektion).to eq true
    end
  end
end
