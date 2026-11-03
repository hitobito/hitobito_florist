# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  class CsvTable
    def self.load(path) = new(path).load

    def initialize(path)
      @path = path
    end

    def load
      table = canonical(parse)
      assert_headers(table)
      table
    end

    private

    def parse
      parser = Import::CsvParser.new(File.read(@path, encoding: "UTF-8"))
      raise Error, "CSV-Datei kann nicht gelesen werden: #{parser.error}" unless parser.parse

      parser.csv
    rescue SystemCallError => e
      raise Error, e.message
    end

    def canonical(table)
      expected = Mappings::REQUIRED_HEADERS.index_by(&:downcase)
      headers = table.headers.map { |header| expected.fetch(header.to_s.downcase, header) }
      assert_unambiguous(table.headers, headers)
      CSV::Table.new(table.map { |row| CSV::Row.new(headers, row.fields) }, headers:)
    end

    def assert_unambiguous(original, headers)
      duplicates = original.group_by.with_index { |_, i| headers[i] }
        .select { |name, columns| Mappings::REQUIRED_HEADERS.include?(name) && columns.size > 1 }
      return if duplicates.empty?

      raise Error, "Spalten mehrfach vorhanden: #{duplicates.values.flatten.join(", ")}"
    end

    def assert_headers(table)
      missing = Mappings::REQUIRED_HEADERS - table.headers
      raise Error, "Fehlende Spalten: #{missing.join(", ")}" if missing.any?
    end
  end
end
