# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  class Report
    HEADER = %w[Adressnumm Status Vorname Nachname Meldungen].freeze

    attr_reader :counts

    def initialize
      @rows = []
      @counts = Hash.new(0)
    end

    def total! = @counts[:total] += 1

    def imported(row, replaced:)
      @counts[:imported] += 1
      @counts[:replaced] += 1 if replaced
      hints = (replaced ? ["Bestehende Person #{row.id} ersetzt"] : []) + row.hints
      return if hints.empty?

      @counts[:with_notes] += 1
      add(row, "HINWEIS", hints)
    end

    def skipped(row, reason)
      @counts[:skipped] += 1
      add(row, "ÜBERSPRUNGEN", [reason])
    end

    def rejected(row, errors)
      @counts[:rejected] += 1
      add(row, "ABGELEHNT", errors)
    end

    def write(path)
      CSV.open(path, "w", encoding: "UTF-8") do |csv|
        csv << HEADER
        @rows.each { |row| csv << row }
      end
    end

    private

    def add(row, status, messages)
      @rows << [row.address_number, status, row.first_name, row.last_name, *messages]
    end
  end
end
