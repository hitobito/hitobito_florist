# frozen_string_literal: true

#  Copyright (c) 2012-2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module Florist::Group
  extend ActiveSupport::Concern

  SECTION_FEE_ATTRS = [
    :section_aktivmitglied_base_fee,
    :section_berufsmitglied_base_fee,
    :section_partnermitglied_base_fee,
    :section_passivmitglied_base_fee,
    :section_full_time_employee_fee,
    :section_part_time_employee_fee,
    :section_branch_fee,
    :section_credit_gv_visit,
    :section_advertising_fee
  ].freeze

  included do
    # Define additional used attributes
    # self.used_attributes += [:website, :bank_account, :description]
    # self.superior_attributes = [:bank_account]

    root_types Group::Dachverband
  end
end
