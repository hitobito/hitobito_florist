# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

class EnablePricesIncludeVatOnInvoiceConfigs < ActiveRecord::Migration[8.1]
  def up
    change_column_default :invoice_configs, :prices_include_vat, true
    execute "UPDATE invoice_configs SET prices_include_vat = TRUE"
  end

  def down
    change_column_default :invoice_configs, :prices_include_vat, false
    execute "UPDATE invoice_configs SET prices_include_vat = FALSE"
  end
end
