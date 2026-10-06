# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"

describe HitobitoFlorist::SettingsContract do
  let(:settings) { Settings.to_hash.deep_dup }
  let(:dachverband_fees) { settings[:florist][:membership_fees][:dachverband] }
  let(:section_fees) { settings[:florist][:membership_fees][:sections] }

  subject(:result) { described_class.new.call(settings) }

  def errors_of(list, index)
    result.errors.to_h.dig(:florist, :membership_fees, list, index)
  end

  it "accepts the configured settings" do
    expect(result).to be_success
  end

  it "still validates the core settings" do
    settings[:people][:inactivity_block][:warn_after] = "invalid"

    expect(result.errors.to_h.dig(:people, :inactivity_block, :warn_after))
      .to include("must be a valid ISO8601 duration string")
  end

  it "rejects an unknown item type" do
    dachverband_fees[0][:item_type] = "Invoice::Bogus"

    expect(errors_of(:dachverband, 0)[:item_type].first).to start_with("must be one of")
  end

  it "rejects a dachverband fee without account" do
    dachverband_fees[0].delete(:account)

    expect(errors_of(:dachverband, 0)[:account]).to include("is missing")
  end

  it "rejects a non-numeric dachverband unit cost" do
    dachverband_fees[0][:dynamic_cost_parameters][:unit_cost] = "abc"

    expect(errors_of(:dachverband, 0)[:dynamic_cost_parameters][:unit_cost])
      .to include("must be a decimal")
  end

  it "rejects a fee without relevant role types" do
    section_fees[0][:dynamic_cost_parameters][:relevant_role_types] = []

    expect(errors_of(:sections, 0)[:dynamic_cost_parameters][:relevant_role_types])
      .to include("size cannot be less than 1")
  end

  it "rejects a field sum item without field" do
    index = section_fees.index { |fee| fee[:item_type] == "Invoice::FieldSumItem" }
    section_fees[index][:dynamic_cost_parameters].delete(:field)

    expect(errors_of(:sections, index)[:dynamic_cost_parameters]).to include("must contain field")
  end

  it "rejects an employee count conditional item without min_employees" do
    index = dachverband_fees.index do |fee|
      fee[:item_type] == "Invoice::EmployeeCountConditionalItem"
    end
    dachverband_fees[index][:dynamic_cost_parameters].delete(:min_employees)

    expect(errors_of(:dachverband, index)[:dynamic_cost_parameters])
      .to include("must contain min_employees")
  end
end
