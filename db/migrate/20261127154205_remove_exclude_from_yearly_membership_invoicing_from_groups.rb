# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

class RemoveExcludeFromYearlyMembershipInvoicingFromGroups < ActiveRecord::Migration[8.1]
  SECTION_FEES = [:section_aktivmitglied_base_fee, :section_berufsmitglied_base_fee,
    :section_partnermitglied_base_fee, :section_passivmitglied_base_fee,
    :section_full_time_employee_fee, :section_part_time_employee_fee,
    :section_branch_fee, :section_credit_gv_visit]

  def up
    execute <<~SQL
      UPDATE groups SET #{SECTION_FEES.map { |attr| "#{attr} = 0" }.join(", ")}
      WHERE exclude_from_yearly_membership_invoicing
    SQL
    remove_column :groups, :exclude_from_yearly_membership_invoicing
  end

  def down
    add_column :groups, :exclude_from_yearly_membership_invoicing, :boolean,
      default: false, null: false
  end
end
