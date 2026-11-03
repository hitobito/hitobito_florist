# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  class Log
    def initialize(path)
      @path = path
    end

    def header(csv_path, dry_run, report_path)
      mode = dry_run ? "Probelauf" : "Import"
      File.write(@path, "")
      append "Florist Import (#{mode}) #{Time.zone.now.strftime("%d.%m.%Y %H:%M")}",
        "Datei: #{csv_path}", "Report: #{report_path}"
    end

    def info(text) = append(text)

    def summary(counts)
      replaced = "ersetzt: #{counts[:replaced]}, " if counts[:replaced].positive?
      text = <<~TEXT
        Zusammenfassung
          Total: #{counts[:total]}
          Importiert: #{counts[:imported]} (davon #{replaced}mit Hinweis: #{counts[:with_notes]})
          Abgelehnt: #{counts[:rejected]}
          Übersprungen: #{counts[:skipped]}
      TEXT
      append "", text
      text
    end

    def abort(message) = append("", "Import abgebrochen: #{message}")

    private

    def append(*lines) = File.open(@path, "a") { |file| file.puts(*lines) }
  end
end
