# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  class Report
    HEADER = %w[Adressnumm Status Vorname Nachname Meldungen].freeze

    def initialize
      @rows = []
    end

    def add(row, status, messages)
      @rows << [row.address_number, status, row.first_name, row.last_name, *messages]
    end

    def write(path)
      CSV.open(path, "w", encoding: "UTF-8") do |csv|
        csv << HEADER
        @rows.each { |row| csv << row }
      end
    end
  end
end
