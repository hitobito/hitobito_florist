# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  class Log
    def initialize(io)
      @io = io
    end

    def header(csv_path, dry_run)
      mode = dry_run ? "Probelauf" : "Import"
      @io.puts "Florist Import (#{mode}) #{Time.zone.now.strftime("%d.%m.%Y %H:%M")}"
      @io.puts "Datei: #{csv_path}"
    end

    def info(text)
      @io.puts text
    end

    def entry(row, status, messages, raw: true)
      @io.puts
      @io.puts ["Zeile #{row.line}", "Adressnumm #{row.id}", row.name, status].join(" | ")
      messages.each { |message| @io.puts "  - #{message}" }
      @io.puts "  > #{row.raw}" if raw
    end

    def summary(counts, force: false)
      replaced = "ersetzt: #{counts[:replaced]}, " if force
      text = <<~TEXT
        Zusammenfassung
          Total: #{counts[:total]}
          Importiert: #{counts[:imported]} (davon #{replaced}mit Hinweis: #{counts[:with_notes]})
          Abgelehnt: #{counts[:rejected]}
          Übersprungen: #{counts[:skipped]}
      TEXT
      @io.puts
      @io.print text
      text
    end

    def abort(message)
      @io.puts
      @io.puts "Import abgebrochen: #{message}"
    end
  end
end
