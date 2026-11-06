# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  class Progress
    TTY_INTERVAL = 0.5
    STEPS = 10

    def initialize(io, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @io = io
      @clock = clock
      @line_open = false
    end

    def phase(text)
      close_line
      @io.puts text
    end

    def start(total)
      @total = total
      @started_at = @clock.call
      @printed_at = nil
      @printed_step = 0
    end

    def step(processed, counts)
      tty? ? step_tty(processed, counts) : step_lines(processed, counts)
    end

    def finish = close_line

    private

    def step_tty(processed, counts)
      now = @clock.call
      return unless processed == @total || @printed_at.nil? || now - @printed_at >= TTY_INTERVAL

      @printed_at = now
      @io.print "\r\e[K#{line(processed, counts)}"
      @io.flush
      @line_open = true
    end

    def step_lines(processed, counts)
      step = processed * STEPS / @total
      return unless step > @printed_step

      @printed_step = step
      @io.puts line(processed, counts)
    end

    def line(processed, counts)
      [
        "Zeilen #{processed}/#{@total} (#{processed * 100 / @total}%)",
        "importiert #{counts[:imported]}",
        "abgelehnt #{counts[:rejected]}",
        "übersprungen #{counts[:skipped]}",
        remaining(processed)
      ].join(" | ")
    end

    def remaining(processed)
      return "Restdauer unbekannt" if processed.zero?

      seconds = (@clock.call - @started_at) / processed * (@total - processed)
      if seconds < 60
        "Restdauer ca. #{seconds.round} Sek."
      else
        "Restdauer ca. #{(seconds / 60).round} Min."
      end
    end

    def close_line
      return unless @line_open

      @io.puts
      @line_open = false
    end

    def tty? = @io.respond_to?(:tty?) && @io.tty?
  end
end
