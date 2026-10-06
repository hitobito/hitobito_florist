# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

# Counts the people holding one of a set of roles, optionally narrowed down by a condition
# on the person, e.g. "everybody who attended the general assembly".
class Invoice::FilterCountItem < Invoice::PeriodItem
  validates :relevant_role_types, presence: true

  # Items with count 0 should not be inserted into the invoice.
  # We achieve this by marking the item as invalid if its count is 0.
  validates :count, numericality: {other_than: 0}

  def relevant_role_types = dynamic_cost_parameters[:relevant_role_types]

  def section_id = dynamic_cost_parameters[:section_id]

  def count
    self[:count] ||= scope.count("DISTINCT(person_id, ancestor.id)")
  end

  private

  def subject_type = Person

  def base_scope
    Role.with_inactive.joins(:group).joins(:person)
      .where(type: relevant_role_types)
      .select(person_id: :id, ancestor: {id: :ancestor_id})
      .distinct
  end

  def scope
    super.where(dynamic_cost_parameters[:where] || {})
  end

  def group_condition
    return super if section_id.blank?

    Group.joins(
      "INNER JOIN groups ancestor ON ancestor.lft <= groups.lft AND ancestor.rgt > groups.lft"
    ).where(ancestor: {id: section_id})
  end

  def active_condition(start_on, end_on)
    roles = Role.arel_table
    # Only roles covering the whole invoicing period are charged. People who joined or left
    # during the period are invoiced manually, there is no automated pro rata calculation.
    Role.with_inactive
      .where(roles[:start_on].lteq(start_on).or(roles[:start_on].eq(nil)))
      .where(roles[:end_on].gteq(end_on).or(roles[:end_on].eq(nil)))
      .where(groups: {exclude_from_yearly_membership_invoicing: false})
  end
end
