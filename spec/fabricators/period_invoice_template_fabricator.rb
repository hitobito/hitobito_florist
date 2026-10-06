# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

Fabricator(:florist_period_invoice_template, from: :period_invoice_template) do
  group { Group.root }
  recipient_source { PeopleFilter.new(group_id: Group.root.id, range: "deep", visible: false) }
  before_create do |period_invoice_template|
    if period_invoice_template.items.empty?
      period_invoice_template.items.build(
        type: PeriodInvoiceTemplate::FeeCalculationItem.name,
        name: PeriodInvoiceTemplate::FeeCalculationItem.model_name.human,
        dynamic_cost_parameters: {unit_cost: "0"}
      )
    end
  end
end
