# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"

describe FloristImport::Preconditions do
  before do
    Person.new(first_name: "Root", email: Settings.root_email).save!(validate: false)
    stub_const("FloristImport::Mappings::SECTIONS", {"6" => "Zürich"})
  end

  def check! = described_class.check!

  it "passes with everything in place" do
    expect { check! }.not_to raise_error
  end

  it "fails on a missing phone category" do
    contact_account_categories(:phone_number_person_business).destroy!
    expect { check! }
      .to raise_error(FloristImport::Error, "Telefonkategorien nicht gefunden: business")
  end

  it "fails on a missing section" do
    stub_const("FloristImport::Mappings::SECTIONS", {"6" => "Zürich", "9" => "Atlantis"})
    expect { check! }.to raise_error(FloristImport::Error, "Sektionen nicht gefunden: Atlantis")
  end

  it "fails on a missing Abonnemente group" do
    root = groups(:kontakte)
    expect { described_class.check!(root) }
      .to raise_error(FloristImport::Error, "Gruppe Abonnemente unter #{root} nicht gefunden")
  end

  it "fails on a missing root user" do
    allow(Person).to receive(:root).and_return(nil)
    expect { check! }
      .to raise_error(FloristImport::Error, "Root-User #{Settings.root_email} nicht gefunden")
  end
end
