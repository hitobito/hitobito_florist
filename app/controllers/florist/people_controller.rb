# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module Florist::PeopleController
  extend ActiveSupport::Concern

  included do
    self.permitted_attrs += Florist::Person::COUNT_ATTRS
  end

  private

  def permitted_attrs
    super +
      [:visited_gv_dachverband].select { can?(:update_gv_dachverband, entry) } +
      [:visited_gv_sektion].select { can?(:update_gv_sektion, entry) }
  end
end
