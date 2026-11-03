# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  class PeopleImporter
    ID_SEQUENCE_MINIMUM = 400_000

    attr_reader :log_path, :counts

    def initialize(csv_path, dry_run: false, force: false, log_path: nil,
      output: $stdout, progress: $stderr)
      @csv_path = csv_path
      @dry_run = dry_run
      @force = force
      @log_path = log_path || default_log_path
      @output = output
      @progress = Progress.new(progress)
      @report = Report.new
      @counts = Hash.new(0)
      @seen_ids = Set.new
    end

    def report_path = Pathname(log_path).sub_ext(".csv")

    def run
      with_regex_email_validation { File.open(log_path, "w") { |file| run_with_log(file) } }
    ensure
      @report.write(report_path)
      @progress.finish
    end

    private

    def run_with_log(file)
      @log = Log.new(file)
      @log.header(@csv_path, @dry_run, report_path)
      import
      print_result(@log.summary(counts, force: @force))
      true
    rescue Error => e
      @log.abort(e.message)
      print_result("Import abgebrochen: #{e.message}")
      false
    end

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
      @progress.phase("Datei wird gelesen …")
      table = canonical_table(parse)
      assert_headers(table)
      in_transaction do
        @progress.phase("Gruppen werden geprüft …")
        groups = resolve_groups
        @builder = PersonBuilder.new(groups)
        import_rows(table, groups)
        @progress.phase("Probelauf wird zurückgerollt …") if @dry_run
      end
      return if @dry_run

      @progress.phase("ID-Sequenz wird gesetzt …")
      update_id_sequence
    end

    def import_rows(table, groups)
      @progress.phase("#{table.size} Zeilen werden importiert …")
      @progress.start(table.size)
      table.each.with_index(2) do |csv_row, line|
        counts[:total] += 1
        import_row(Row.new(csv_row, line:, groups:))
        @progress.step(counts[:total], counts)
      end
    end

    def parse
      parser = Import::CsvParser.new(File.read(@csv_path, encoding: "UTF-8"))
      raise Error, "CSV-Datei kann nicht gelesen werden: #{parser.error}" unless parser.parse

      parser.csv
    rescue SystemCallError => e
      raise Error, e.message
    end

    def canonical_table(table)
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

    def in_transaction(&)
      return yield unless @dry_run

      ActiveRecord::Base.transaction(requires_new: true) do
        yield
        raise ActiveRecord::Rollback
      end
    end

    def resolve_groups
      Groups.resolve.tap do |groups|
        groups.created_groups.each do |group|
          @log.info("Gruppe #{group} unter #{group.parent} angelegt")
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

      errors, hints = save_row(row, existing, @builder.qualification_kinds(row))
      errors.any? ? reject(row, errors) : imported(row, hints, replaced: existing.present?)
    rescue => e
      reject(row, ["#{e.class}: #{e.message}"])
    end

    def duplicate?(row) = row.id && !@seen_ids.add?(row.id)

    def skip_reason(row, existing)
      if row.skip_reason
        row.skip_reason
      elsif existing && !@force
        "Person #{row.id} existiert bereits"
      end
    end

    def save_row(row, existing, kinds)
      result = [[], []]
      ActiveRecord::Base.transaction(requires_new: true) do
        People::Destroyer.new(existing).run if existing
        result = build_and_save(row, kinds)
        raise ActiveRecord::Rollback if result.first.any?
      end
      result
    end

    def build_and_save(row, kinds)
      email_taken = row.email.present? && ::Person.exists?(email: row.email)
      check = ContactCheck.new(row, email_taken:)
      person = @builder.build(row, check, kinds)
      errors = row.errors + @builder.errors(person)
      errors = person.errors.full_messages if errors.empty? && !person.save
      [errors, check.hints]
    end

    def imported(row, hints, replaced:)
      counts[:imported] += 1
      counts[:replaced] += 1 if replaced
      notes = (replaced ? ["Bestehende Person #{row.id} ersetzt"] : []) + row.notes + hints
      return if notes.empty?

      counts[:with_notes] += 1
      @report.add(row, "HINWEIS", notes)
    end

    def skip(row, reason)
      counts[:skipped] += 1
      @report.add(row, "ÜBERSPRUNGEN", [reason])
    end

    def reject(row, errors)
      counts[:rejected] += 1
      @report.add(row, "ABGELEHNT", errors)
    end

    def update_id_sequence
      next_id = [ID_SEQUENCE_MINIMUM, ::Person.maximum(:id).to_i + 1].max
      ::Person.connection.execute(
        "SELECT setval(pg_get_serial_sequence('people', 'id'), #{next_id}, false)"
      )
    end

    def print_result(text)
      @output.puts text
      @output.puts "Log: #{log_path}"
      @output.puts "Report: #{report_path}"
    end

    def default_log_path
      Rails.root.join("log", "florist_import_#{Time.zone.now.strftime("%Y%m%d-%H%M%S")}.log")
    end
  end
end
