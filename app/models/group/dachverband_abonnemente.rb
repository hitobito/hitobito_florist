# frozen_string_literal: true

#  Copyright (c) 2012-2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

class Group::DachverbandAbonnemente < ::Group
  ### ROLES

  class JahresaboSchweiz < ::Role
  end

  class JahresaboMitglied < ::Role
  end

  class JahresaboEuropa < ::Role
  end

  class Probeabo < ::Role
  end

  class Lehrlingsabo < ::Role
  end

  class Gratisabo < ::Role
  end

  class LehrgangFloristik < ::Role
  end

  class BMplus < ::Role
  end

  roles JahresaboSchweiz, JahresaboMitglied, JahresaboEuropa, Probeabo, Lehrlingsabo, Gratisabo,
    LehrgangFloristik, BMplus
end
