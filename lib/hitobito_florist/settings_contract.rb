# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

class HitobitoFlorist::SettingsContract < SettingsContract
  ITEM_TYPES = %w[
    Invoice::FilterCountItem
    Invoice::FieldSumItem
    Invoice::EmployeeCountConditionalItem
  ].freeze

  ITEM_PARAMETERS = Dry::Schema.Params do
    required(:relevant_role_types).value(:array, min_size?: 1).each(:string)
    optional(:field).filled(:string)
    optional(:min_employees).filled(:integer)
    optional(:max_employees).filled(:integer)
    optional(:where).hash
  end

  params(SettingsContract.__schema__) do
    required(:florist).hash do
      required(:membership_fees).hash do
        required(:dachverband).array(:hash) do
          required(:name).filled(:string)
          required(:item_type).filled(:string, included_in?: ITEM_TYPES)
          required(:account).filled(:string)
          required(:cost_center).filled(:string)
          optional(:vat_rate).filled(:decimal)
          required(:dynamic_cost_parameters).hash(ITEM_PARAMETERS) do
            required(:unit_cost).filled(:decimal)
          end
        end

        required(:sections).array(:hash) do
          required(:name).filled(:string)
          required(:item_type).filled(:string, included_in?: ITEM_TYPES)
          required(:dynamic_cost_parameters).hash(ITEM_PARAMETERS) do
            required(:unit_cost).filled(:string)
          end
        end
      end
    end
  end

  %w[dachverband sections].each do |list|
    rule("florist.membership_fees.#{list}").each do
      parameters = value[:dynamic_cost_parameters]
      parameters_key = key([*key.path.to_a, :dynamic_cost_parameters])

      case value[:item_type]
      when "Invoice::FieldSumItem"
        parameters_key.failure("must contain field") if parameters[:field].blank?
      when "Invoice::EmployeeCountConditionalItem"
        parameters_key.failure("must contain min_employees") if parameters[:min_employees].nil?
      end
    end
  end
end
