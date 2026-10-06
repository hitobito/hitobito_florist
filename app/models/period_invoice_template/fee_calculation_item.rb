# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

class PeriodInvoiceTemplate::FeeCalculationItem < PeriodInvoiceTemplate::Item
  def to_invoice_item_for_people(invoice: nil, recipient_people: Person.none, attrs: {})
    fee_items.map do |fee|
      item_attrs = invoice_item_attrs(invoice:, attrs: attrs.deep_merge(fee.except(:item_type)))
      fee[:item_type].constantize.for_people(recipient_people, **item_attrs)
    end
  end

  def to_invoice_item_for_groups(invoice: nil, recipient_groups: nil, attrs: {})
    raise "florist.ch only sends membership fee invoices to people, not to groups"
  end

  private

  def fee_items
    @fee_items ||= Florist::MembershipFeeItems.new(period_invoice_template.group).to_a
  end
end
