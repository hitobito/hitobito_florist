# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

class RemoveSectionAdvertisingFeeFromGroups < ActiveRecord::Migration[8.1]
  def change
    remove_column :groups, :section_advertising_fee, :decimal, precision: 12, scale: 2
  end
end
