# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"

describe PersonAbility do
  let(:aargau) { groups(:aargau) }
  let(:zuerich) { groups(:zuerich) }

  let(:member) { Fabricate(Group::Sektion::Aktivmitglied.sti_name, group: aargau).person }

  subject(:ability) { Ability.new(user.reload) }

  context "Dachverband employee" do
    let(:user) { people(:member) } # Group::Dachverband::Mitarbeiter

    it "may update both gv visit flags of a section member" do
      is_expected.to be_able_to(:update_gv_dachverband, member)
      is_expected.to be_able_to(:update_gv_sektion, member)
    end
  end

  context "Dachverband administrator" do
    let(:user) { people(:admin) }

    it "may update both gv visit flags of a section member" do
      is_expected.to be_able_to(:update_gv_dachverband, member)
      is_expected.to be_able_to(:update_gv_sektion, member)
    end
  end

  context "Sektion role" do
    let(:user) { Fabricate(Group::Sektion::Sektion.sti_name, group: aargau).person }

    it "may update the section gv visit flag of a member of the same section" do
      is_expected.to be_able_to(:update_gv_sektion, member)
    end

    it "may not update the umbrella organisation gv visit flag" do
      is_expected.not_to be_able_to(:update_gv_dachverband, member)
    end

    it "may not update the gv visit flag of a member of another section" do
      other = Fabricate(Group::Sektion::Aktivmitglied.sti_name, group: zuerich).person
      is_expected.not_to be_able_to(:update_gv_sektion, other)
    end
  end

  context "member" do
    let(:user) { member }

    it "may update herself but neither of the gv visit flags" do
      is_expected.to be_able_to(:update, member)
      is_expected.not_to be_able_to(:update_gv_dachverband, member)
      is_expected.not_to be_able_to(:update_gv_sektion, member)
    end
  end
end
