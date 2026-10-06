# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

class AddFloristInvoicingAttrs < ActiveRecord::Migration[7.1]
  PERSON_COUNTS = [:full_time_employees, :part_time_employees, :apprentices, :branches]

  SECTION_FEES = [:section_aktivmitglied_base_fee, :section_berufsmitglied_base_fee,
    :section_partnermitglied_base_fee, :section_passivmitglied_base_fee,
    :section_full_time_employee_fee, :section_part_time_employee_fee,
    :section_branch_fee, :section_credit_gv_visit, :section_advertising_fee]

  def change
    PERSON_COUNTS.each do |attr|
      add_column :people, attr, :integer, default: 0, null: false
    end
    add_column :people, :visited_gv_dachverband, :boolean, default: false, null: false
    add_column :people, :visited_gv_sektion, :boolean, default: false, null: false

    SECTION_FEES.each do |attr|
      add_column :groups, attr, :decimal, precision: 12, scale: 2
    end
    add_column :groups, :section_fee_account, :string
    add_column :groups, :exclude_from_yearly_membership_invoicing, :boolean,
      default: false, null: false
  end
end
