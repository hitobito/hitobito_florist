# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  class Cells
    INTEGER_FORMAT = /\A\d+(\.0+)?\z/
    UNSET_CODE = "_"

    attr_reader :errors

    def initialize(csv_row, errors: [])
      @csv_row = csv_row
      @errors = errors
      @dates = {}
    end

    def value(column) = @csv_row.fetch(column)&.strip.presence

    def integer_code(column)
      raw = value(column)
      raw&.match?(INTEGER_FORMAT) ? raw.to_i.to_s : raw
    end

    def integer(column, required: false)
      raw = value(column)
      return raw.to_i if raw&.match?(INTEGER_FORMAT)

      if raw
        @errors << "#{column} '#{raw}' ist keine ganze Zahl"
      elsif required
        @errors << "#{column} fehlt"
      end
      required ? nil : 0
    end

    def date(column)
      return @dates[column] if @dates.key?(column)

      @dates[column] = parse_date(column)
    end

    def codes(column) = value(column).to_s.upcase.delete(UNSET_CODE).chars.uniq

    def set?(column)
      raw = value(column)
      raw.present? && Mappings::UNSET_VALUES.exclude?(raw.downcase)
    end

    private

    def parse_date(column)
      raw = value(column)
      return if raw.nil?

      Date.strptime(raw, Mappings::DATE_FORMAT)
    rescue Date::Error
      @errors << "#{column} '#{raw}' ist kein Datum im Format #{Mappings::DATE_FORMAT_LABEL}"
      nil
    end
  end
end
