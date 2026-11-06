# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  class PeopleImporter
    ID_SEQUENCE_MINIMUM = 400_000

    attr_reader :log_path

    def initialize(csv_path, dry_run: false, force: false, log_path: nil,
      output: $stdout, progress: $stderr)
      @csv_path = csv_path
      @dry_run = dry_run
      @force = force
      @log_path = log_path || default_log_path
      @output = output
      @progress = Progress.new(progress)
      @report = Report.new
      @log = Log.new(@log_path)
      @seen_ids = Set.new
    end

    def counts = @report.counts

    def report_path = Pathname(log_path).sub_ext(".csv")

    def run
      with_regex_email_validation do
        @log.header(@csv_path, @dry_run, report_path)
        import
        print_result(@log.summary(counts))
        true
      rescue Error => e
        @log.abort(e.message)
        print_result("Import abgebrochen: #{e.message}")
        false
      end
    ensure
      @report.write(report_path)
      @progress.finish
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
      @progress.phase("Datei wird gelesen …")
      table = CsvTable.load(@csv_path)
      @progress.phase("Gruppen werden geprüft …")
      Preconditions.check!
      with_dry_run_rollback do
        @builder = PersonBuilder.new(resolve_groups)
        import_rows(table)
        @progress.phase("Probelauf wird zurückgerollt …") if @dry_run
      end
      return if @dry_run

      @progress.phase("ID-Sequenz wird gesetzt …")
      update_id_sequence
    end

    def import_rows(table)
      @progress.phase("#{table.size} Zeilen werden importiert …")
      @progress.start(table.size)
      table.each.with_index(2) do |csv_row, line|
        @report.total!
        import_row(Row.new(csv_row, line:))
        @progress.step(counts[:total], counts)
      end
    end

    def with_dry_run_rollback(&)
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
        return @report.rejected(row, ["Adressnumm #{row.id} kommt mehrfach in der Datei vor"])
      end

      existing = row.id && ::Person.find_by(id: row.id)
      reason = skip_reason(row, existing)
      reason ? @report.skipped(row, reason) : import_person(row, existing)
    rescue => e
      @report.rejected(row, ["#{e.class}: #{e.message}"])
    end

    def import_person(row, existing)
      checked = CheckedRow.new(row, email_taken: email_taken?(row))
      errors = save_row(checked, existing, @builder.qualification_kinds(row))
      if errors.any?
        @report.rejected(row, errors)
      else
        @report.imported(checked, replaced: existing.present?)
      end
    end

    def duplicate?(row) = row.id && !@seen_ids.add?(row.id)

    def skip_reason(row, existing)
      if row.skip_reason
        row.skip_reason
      elsif existing && !@force
        "Person #{row.id} existiert bereits"
      end
    end

    def email_taken?(row)
      row.email.present? && ::Person.where(email: row.email).where.not(id: row.id).exists?
    end

    def save_row(checked, existing, kinds)
      errors = []
      ActiveRecord::Base.transaction(requires_new: true) do
        People::Destroyer.new(existing).run if existing
        errors = build_and_save(checked, kinds)
        raise ActiveRecord::Rollback if errors.any?
      end
      errors
    end

    def build_and_save(checked, kinds)
      person = @builder.build(checked, kinds)
      if checked.errors.any?
        person.valid?
        checked.errors + @builder.error_messages(person)
      else
        person.save ? [] : @builder.error_messages(person)
      end
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
