# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"

describe Group::Sektion do
  let(:aargau) { groups(:aargau) }

  it "has a writing Sektion role" do
    expect(Group::Sektion.role_types).to include(Group::Sektion::Sektion)
    expect(Group::Sektion::Sektion.permissions).to eq [:layer_full]
  end

  describe "membership fee attributes" do
    it "holds the unit costs this section charges its members, credits as negative amounts" do
      expect(aargau.section_aktivmitglied_base_fee).to eq 200
      expect(aargau.section_berufsmitglied_base_fee).to eq 50
      expect(aargau.section_partnermitglied_base_fee).to eq 50
      expect(aargau.section_passivmitglied_base_fee).to eq 50
      expect(aargau.section_full_time_employee_fee).to eq 50
      expect(aargau.section_part_time_employee_fee).to eq 25
      expect(aargau.section_branch_fee).to eq 50
      expect(aargau.section_credit_gv_visit).to eq(-100)
      expect(aargau.section_advertising_fee).to eq(0)
      expect(groups(:zuerich).section_advertising_fee).to eq 60
    end

    it "keeps fractional amounts" do
      aargau.update!(section_branch_fee: 12.55)
      expect(aargau.reload.section_branch_fee).to eq 12.55
    end

    it "holds the booking account for the section items" do
      expect(aargau.section_fee_account).to eq "2291"
    end

    it "excludes the sections which invoice their members themselves" do
      expect(groups(:nordwestschweiz)).to be_exclude_from_yearly_membership_invoicing
      expect(groups(:zentralschweiz)).to be_exclude_from_yearly_membership_invoicing
      expect(aargau).not_to be_exclude_from_yearly_membership_invoicing
    end

    it "does not offer the attributes in the group UI" do
      expect(Group::Sektion.used_attributes)
        .not_to include(*Florist::Group::SECTION_FEE_ATTRS)
    end
  end
end
