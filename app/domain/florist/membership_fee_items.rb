# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

# Turns the membership fee definitions in settings.yml into attributes for the invoice items
# a PeriodInvoiceTemplate::FeeCalculationItem generates, see
# https://github.com/hitobito/hitobito_florist/issues/6.
#
# The items of the Sektionen are generated once per Sektion, with the unit cost and the
# booking account read from that Sektion.
class Florist::MembershipFeeItems
  TRANSLATION_SCOPE = "florist.membership_fee_items"

  def initialize(group)
    @group = group
  end

  def to_a
    dachverband_items + section_items
  end

  private

  def dachverband_items
    definitions(:dachverband).map { |fee| item(fee, configured_unit_cost(fee)) }
  end

  def section_items
    sections.flat_map do |section|
      definitions(:sections).filter_map do |fee|
        unit_cost = section_unit_cost(section, configured_unit_cost(fee))
        # A section which does not grant a credit or charge a fee should not show the item
        # at all, not even on the invoice run preview.
        next if unit_cost.nil? || unit_cost.zero?

        item(fee, unit_cost, section)
      end
    end
  end

  def sections
    @group.self_and_descendants
      .where(type: Group::Sektion.sti_name, exclude_from_yearly_membership_invoicing: false)
      .order(:lft)
  end

  def definitions(key)
    Settings.florist.membership_fees.send(key).map { |fee| fee.to_h.deep_symbolize_keys }
  end

  def configured_unit_cost(fee)
    fee.dig(:dynamic_cost_parameters, :unit_cost)
  end

  def section_unit_cost(section, attr)
    attr = attr.to_sym
    raise ArgumentError, "unknown section fee #{attr}" unless
      Florist::Group::SECTION_FEE_ATTRS.include?(attr)

    section.send(attr)
  end

  def item(fee, unit_cost, section = nil)
    fee.merge(
      **names(fee[:name], section),
      account: section ? section.section_fee_account : fee[:account],
      unit_cost:,
      dynamic_cost_parameters: fee[:dynamic_cost_parameters].to_h
        .merge(section ? {unit_cost:, section_id: section.id} : {unit_cost:})
    )
  end

  def names(key, section)
    Globalized.languages
      .to_h { |locale| [:"name_#{locale}", translate(key, section, locale)] }
      .merge(name: translate(key, section, I18n.locale))
  end

  def translate(key, section, locale)
    I18n.t(key, scope: TRANSLATION_SCOPE, locale: locale, section: section&.name)
  end
end
