# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"
require "rake"

describe "florist:import_people" do
  Rake::Task.define_task(:environment)
  Rake.application.rake_require("tasks/import_people",
    [HitobitoFlorist::Wagon.root.join("lib").to_s])

  let(:importer) { instance_double(FloristImport::PeopleImporter, run: true) }

  before do
    Rake::Task["florist:import_people"].reenable
    Rake::Task["florist:import_people:dryrun"].reenable
    Rake::Task["florist:import_people:force"].reenable
    allow(FloristImport::PeopleImporter).to receive(:new).and_return(importer)
  end

  it "imports the given file" do
    Rake::Task["florist:import_people"].invoke("export.csv")
    expect(FloristImport::PeopleImporter).to have_received(:new)
      .with("export.csv", dry_run: false, force: false)
    expect(importer).to have_received(:run)
  end

  it "passes the log file" do
    Rake::Task["florist:import_people"].invoke("export.csv", "import.log")
    expect(FloristImport::PeopleImporter).to have_received(:new)
      .with("export.csv", dry_run: false, force: false, log_path: "import.log")
  end

  it "runs the dry run" do
    Rake::Task["florist:import_people:dryrun"].invoke("export.csv")
    expect(FloristImport::PeopleImporter).to have_received(:new)
      .with("export.csv", dry_run: true, force: false)
  end

  it "runs the force import" do
    Rake::Task["florist:import_people:force"].invoke("export.csv")
    expect(FloristImport::PeopleImporter).to have_received(:new)
      .with("export.csv", dry_run: false, force: true)
  end

  it "aborts the force import without csv file" do
    expect { Rake::Task["florist:import_people:force"].invoke }
      .to raise_error(SystemExit)
      .and output(/Usage: rake "florist:import_people:force\[CSV_FILE,LOG_FILE\]"/).to_stderr
  end

  it "aborts without csv file" do
    expect { Rake::Task["florist:import_people:dryrun"].invoke }
      .to raise_error(SystemExit)
      .and output(/Usage: rake "florist:import_people:dryrun\[CSV_FILE,LOG_FILE\]"/).to_stderr
    expect(FloristImport::PeopleImporter).not_to have_received(:new)
  end

  it "exits with failure if the import aborts" do
    allow(importer).to receive(:run).and_return(false)
    expect { Rake::Task["florist:import_people"].invoke("export.csv") }
      .to raise_error(SystemExit) { |error| expect(error.status).to eq 1 }
  end
end
