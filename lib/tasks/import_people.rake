# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

namespace :florist do
  import_people = lambda do |task, args, dry_run: false, force: false|
    abort("Usage: rake \"#{task.name}[CSV_FILE,LOG_FILE]\"") if args[:csv_file].blank?

    options = {dry_run:, force:, log_path: args[:log_file].presence}.compact
    FloristImport::PeopleImporter.new(args[:csv_file], **options).run || abort
  end

  desc "Import people, roles and qualifications from the florist.ch CSV export"
  task :import_people, [:csv_file, :log_file] => :environment do |task, args|
    import_people.call(task, args)
  end

  namespace :import_people do
    desc "Process the florist.ch CSV export like florist:import_people without saving anything"
    task :dryrun, [:csv_file, :log_file] => :environment do |task, args|
      import_people.call(task, args, dry_run: true)
    end

    desc "Import the florist.ch CSV export like florist:import_people, " \
      "replacing existing people with the same id"
    task :force, [:csv_file, :log_file] => :environment do |task, args|
      import_people.call(task, args, force: true)
    end
  end
end
