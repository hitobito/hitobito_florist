# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  class PeopleImporter
    ID_SEQUENCE_MINIMUM = 400_000

    attr_reader :log_path, :counts

    def initialize(csv_path, dry_run: false, force: false, log_path: nil, output: $stdout)
      @csv_path = csv_path
      @dry_run = dry_run
      @force = force
      @log_path = log_path || default_log_path
      @output = output
      @counts = Hash.new(0)
      @builder = PersonBuilder.new
      @seen_ids = Set.new
    end

    def run
      with_regex_email_validation do
        File.open(log_path, "w") do |file|
          @log = Log.new(file)
          @log.header(@csv_path, @dry_run)
          import
          report(@log.summary(counts, force: @force))
          true
        rescue Error => e
          @log.abort(e.message)
          report("Import abgebrochen: #{e.message}")
          false
        end
      end
    end

    private

    def with_regex_email_validation
      previous = Truemail.configuration.default_validation_type
      Truemail.configuration.default_validation_type = :regex
      begin
        yield
      ensure
        Truemail.configuration.default_validation_type = previous
      end
    end

    def import
      table = parse
      assert_headers(table)
      in_transaction do
        groups = resolve_groups
        table.each.with_index(2) do |csv_row, line|
          counts[:total] += 1
          import_row(Row.new(csv_row, line:, groups:))
        end
      end
      update_id_sequence unless @dry_run
    end

    def parse
      parser = Import::CsvParser.new(File.read(@csv_path, encoding: "UTF-8"))
      raise Error, "CSV-Datei kann nicht gelesen werden: #{parser.error}" unless parser.parse

      parser.csv
    rescue SystemCallError => e
      raise Error, e.message
    end

    def assert_headers(table)
      missing = Mappings::REQUIRED_HEADERS - table.headers
      raise Error, "Fehlende Spalten: #{missing.join(", ")}" if missing.any?
    end

    def in_transaction(&)
      return yield unless @dry_run

      ActiveRecord::Base.transaction(requires_new: true) do
        yield
        raise ActiveRecord::Rollback
      end
    end

    def resolve_groups
      Groups.resolve.tap do |groups|
        if groups.interessenten_created?
          @log.info("Gruppe #{groups.interessenten} unter #{groups.interessenten.parent} angelegt")
        end
      end
    end

    def import_row(row)
      if duplicate?(row)
        return reject(row, ["Adressnumm #{row.id} kommt mehrfach in der Datei vor"])
      end

      existing = row.id && ::Person.find_by(id: row.id)
      reason = skip_reason(row, existing)
      return skip(row, reason) if reason

      errors = save_row(row, existing, @builder.qualification_kinds(row))
      errors.any? ? reject(row, errors) : imported(row, replaced: existing.present?)
    rescue => e
      reject(row, ["#{e.class}: #{e.message}"])
    end

    def duplicate?(row) = row.id && !@seen_ids.add?(row.id)

    def skip_reason(row, existing)
      if row.deceased?
        "Verstorben (Code 4 Mit '#{Mappings::DECEASED_CODE}')"
      elsif existing && !@force
        "Person #{row.id} existiert bereits"
      end
    end

    def save_row(row, existing, kinds)
      errors = []
      ActiveRecord::Base.transaction(requires_new: true) do
        People::Destroyer.new(existing).run if existing
        errors = build_and_save(row, kinds)
        raise ActiveRecord::Rollback if errors.any?
      end
      errors
    end

    def build_and_save(row, kinds)
      email_taken = row.email.present? && ::Person.exists?(email: row.email)
      person = @builder.build(row, kinds, email_taken:)
      errors = row.errors + email_conflicts(row, email_taken) + @builder.errors(person)
      return errors if errors.any?

      person.save ? [] : person.errors.full_messages
    end

    def email_conflicts(row, email_taken)
      email_taken ? ["Email-Adre #{row.email} ist bereits vergeben"] : []
    end

    def imported(row, replaced:)
      counts[:imported] += 1
      counts[:replaced] += 1 if replaced
      notes = (replaced ? ["Bestehende Person #{row.id} ersetzt"] : []) + row.notes
      return if notes.empty?

      counts[:with_notes] += 1
      @log.entry(row, "HINWEIS", notes, raw: false)
    end

    def skip(row, reason)
      counts[:skipped] += 1
      @log.entry(row, "ÜBERSPRUNGEN", [reason])
    end

    def reject(row, errors)
      counts[:rejected] += 1
      @log.entry(row, "ABGELEHNT", errors)
    end

    def update_id_sequence
      next_id = [ID_SEQUENCE_MINIMUM, ::Person.maximum(:id).to_i + 1].max
      ::Person.connection.execute(
        "SELECT setval(pg_get_serial_sequence('people', 'id'), #{next_id}, false)"
      )
    end

    def report(text)
      @output.puts text
      @output.puts "Log: #{log_path}"
    end

    def default_log_path
      Rails.root.join("log", "florist_import_#{Time.zone.now.strftime("%Y%m%d-%H%M%S")}.log")
    end
  end
end
