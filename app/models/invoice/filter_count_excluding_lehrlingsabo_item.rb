# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

# Apprentices do not pay any fees until the end of the calendar year after their Lehrlingsabo
# starts, and only a reduced fee in later years. The calendar year of the period end decides
# which year of the Lehrlingsabo is being invoiced.
class Invoice::FilterCountExcludingLehrlingsaboItem < Invoice::FilterCountItem
  def only_exclude_first_year_lehrlingsabos?
    ActiveModel::Type::Boolean.new.cast(
      dynamic_cost_parameters[:only_exclude_first_year_lehrlingsabos]
    )
  end

  private

  def scope
    super.where.not(person_id: lehrlingsabos.select(:person_id))
  end

  def lehrlingsabos
    abos = Role.with_inactive
      .where(type: Group::DachverbandAbonnemente::Lehrlingsabo.sti_name)
      .merge(active_during_period)
    return abos unless only_exclude_first_year_lehrlingsabos?

    abos.where(start_on: free_membership_start_years)
  end

  def free_membership_start_years
    year_end = period_end_on.to_date.end_of_year
    year_end.prev_year.beginning_of_year..year_end
  end

  def active_during_period
    roles = Role.arel_table
    Role.with_inactive
      .where(roles[:start_on].lteq(period_end_on).or(roles[:start_on].eq(nil)))
      .where(roles[:end_on].gteq(period_start_on).or(roles[:end_on].eq(nil)))
  end
end
