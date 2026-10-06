# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

class Invoice::FieldSumItem < Invoice::FilterCountItem
  def field = dynamic_cost_parameters[:field].to_s

  def count
    self[:count] ||= Role.unscoped.from(deduplicated_scope, :deduplicated).sum(:field_value).to_i
  end

  private

  def deduplicated_scope
    scope.reselect(
      Role.arel_table[:person_id],
      Arel.sql("ancestor.id AS ancestor_id"),
      Person.arel_table[field].as("field_value")
    )
  end
end
