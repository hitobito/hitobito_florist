# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

class Invoice::EmployeeCountConditionalItem < Invoice::FilterCountItem
  validates :min_employees, presence: true

  def min_employees = dynamic_cost_parameters[:min_employees]

  def max_employees = dynamic_cost_parameters[:max_employees]

  private

  def scope
    condition = super.where(employees.gteq(min_employees.to_i))
    max_employees ? condition.where(employees.lteq(max_employees.to_i)) : condition
  end

  def employees
    Person.arel_table[:full_time_employees] + Person.arel_table[:part_time_employees]
  end
end
