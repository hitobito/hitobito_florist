# frozen_string_literal: true

#  Copyright (c) 2012-2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

class Group::Sektion < ::Group
  self.layer = true

  ### ROLES

  class Aktivmitglied < ::Role
  end

  class Berufsmitglied < ::Role
  end

  class Berufsmitgliedplus < ::Role
  end

  class StartUp < ::Role
  end

  class Ehrenmitglied < ::Role
  end

  class Filiale < ::Role
  end

  class Entdecker < ::Role
  end

  class Partnermitglied < ::Role
  end

  class Passivmitglied < ::Role
  end

  class ExMitglied < ::Role
  end

  roles Aktivmitglied, Berufsmitglied, Berufsmitgliedplus, StartUp, Ehrenmitglied, Filiale,
    Entdecker, Partnermitglied, Passivmitglied, ExMitglied
end
