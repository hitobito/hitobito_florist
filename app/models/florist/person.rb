# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module Florist::Person
  extend ActiveSupport::Concern

  COUNT_ATTRS = [:full_time_employee_count, :part_time_employee_count, :apprentice_count,
    :branch_count].freeze
  GV_ATTRS = [:visited_gv_dachverband, :visited_gv_sektion].freeze

  included do
    validates(*COUNT_ATTRS, numericality: {greater_than_or_equal_to: 0})

    before_validation :default_florist_counts_to_zero
  end

  private

  def default_florist_counts_to_zero
    COUNT_ATTRS.each { |attr| self[attr] = 0 if self[attr].nil? }
  end
end
