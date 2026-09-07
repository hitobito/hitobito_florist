# frozen_string_literal: true

#  Copyright (c) 2012-2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

class Group::Dachverband < ::Group
  self.layer = true
  children DachverbandKontakte,
    DachverbandAbonnemente,
    Sektion

  self.default_children = [DachverbandKontakte, DachverbandAbonnemente]

  ### ROLES

  class Administrator < ::Role
    self.permissions = [:admin, :layer_and_below_full, :finance, :approve_applications,
      :impersonation]
  end

  class Mitarbeiter < ::Role
    self.permissions = [:admin, :layer_and_below_full, :finance, :approve_applications]
  end

  roles Administrator, Mitarbeiter
end
