# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module Florist::PersonAbility
  extend ActiveSupport::Concern

  included do
    on(Person) do
      permission(:layer_and_below_full)
        .may(:update_gv_dachverband, :update_gv_sektion)
        .non_restricted_in_same_layer_or_visible_below

      permission(:layer_full)
        .may(:update_gv_sektion)
        .non_restricted_in_same_layer
    end
  end
end
