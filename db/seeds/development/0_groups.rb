# frozen_string_literal: true

#  Copyright (c) 2012-2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require Rails.root.join("db", "seeds", "support", "group_seeder")

seeder = GroupSeeder.new

root = Group.roots.first
srand(42)

if root.address.blank?
  root.update(seeder.group_attributes)
  root.default_children.each do |child_class|
    child_class.first.update(seeder.group_attributes)
  end
end

# Fee attributes of the sections, see https://github.com/hitobito/hitobito_florist/issues/5
section_fees = {
  "Aargau" => {
    section_aktivmitglied_base_fee: 200,
    section_berufsmitglied_base_fee: 50,
    section_partnermitglied_base_fee: 50,
    section_passivmitglied_base_fee: 50,
    section_full_time_employee_fee: 50,
    section_part_time_employee_fee: 25,
    section_branch_fee: 50,
    section_credit_gv_visit: -100,
    section_advertising_fee: 0,
    section_fee_account: "2291",
    exclude_from_yearly_membership_invoicing: false
  },
  "Nordwestschweiz" => {
    section_aktivmitglied_base_fee: 100,
    section_berufsmitglied_base_fee: 50,
    section_partnermitglied_base_fee: 0,
    section_passivmitglied_base_fee: 0,
    section_full_time_employee_fee: 40,
    section_part_time_employee_fee: 20,
    section_branch_fee: 20,
    section_credit_gv_visit: 0,
    section_advertising_fee: 0,
    section_fee_account: "2292",
    exclude_from_yearly_membership_invoicing: true
  },
  "Mittelland/Wallis" => {
    section_aktivmitglied_base_fee: 200,
    section_berufsmitglied_base_fee: 50,
    section_partnermitglied_base_fee: 200,
    section_passivmitglied_base_fee: 50,
    section_full_time_employee_fee: 40,
    section_part_time_employee_fee: 20,
    section_branch_fee: 0,
    section_credit_gv_visit: -100,
    section_advertising_fee: 0,
    section_fee_account: "2293",
    exclude_from_yearly_membership_invoicing: false
  },
  "Zentralschweiz" => {
    section_aktivmitglied_base_fee: 220,
    section_berufsmitglied_base_fee: 50,
    section_partnermitglied_base_fee: 50,
    section_passivmitglied_base_fee: 50,
    section_full_time_employee_fee: 40,
    section_part_time_employee_fee: 25,
    section_branch_fee: 60,
    section_credit_gv_visit: -50,
    section_advertising_fee: 100,
    section_fee_account: "2294",
    exclude_from_yearly_membership_invoicing: true
  },
  "Ostschweiz" => {
    section_aktivmitglied_base_fee: 150,
    section_berufsmitglied_base_fee: 50,
    section_partnermitglied_base_fee: 100,
    section_passivmitglied_base_fee: 40,
    section_full_time_employee_fee: 30,
    section_part_time_employee_fee: 15,
    section_branch_fee: 0,
    section_credit_gv_visit: -50,
    section_advertising_fee: 0,
    section_fee_account: "2295",
    exclude_from_yearly_membership_invoicing: false
  },
  "Zürich" => {
    section_aktivmitglied_base_fee: 150,
    section_berufsmitglied_base_fee: 50,
    section_partnermitglied_base_fee: 50,
    section_passivmitglied_base_fee: 40,
    section_full_time_employee_fee: 40,
    section_part_time_employee_fee: 20,
    section_branch_fee: 50,
    section_credit_gv_visit: -50,
    section_advertising_fee: 60,
    section_fee_account: "2296",
    exclude_from_yearly_membership_invoicing: false
  },
  "Ticino" => {
    section_aktivmitglied_base_fee: 100,
    section_berufsmitglied_base_fee: 50,
    section_partnermitglied_base_fee: 100,
    section_passivmitglied_base_fee: 100,
    section_full_time_employee_fee: 40,
    section_part_time_employee_fee: 20,
    section_branch_fee: 50,
    section_credit_gv_visit: 0,
    section_advertising_fee: 0,
    section_fee_account: "2297",
    exclude_from_yearly_membership_invoicing: false
  },
  "Suisse Romande" => {
    section_aktivmitglied_base_fee: 255,
    section_berufsmitglied_base_fee: 50,
    section_partnermitglied_base_fee: 100,
    section_passivmitglied_base_fee: 40,
    section_full_time_employee_fee: 45,
    section_part_time_employee_fee: 25,
    section_branch_fee: 50,
    section_credit_gv_visit: -50,
    section_advertising_fee: 0,
    section_fee_account: "2298",
    exclude_from_yearly_membership_invoicing: false
  }
}

section_fees.each do |name, attrs|
  Group::Sektion.seed_once(:name, parent_id: root.id, name: name)
  Group::Sektion.find_by(parent_id: root.id, name: name).update!(attrs)
end

Group.rebuild!
