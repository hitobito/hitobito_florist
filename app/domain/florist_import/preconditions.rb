# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  class Preconditions
    def self.check!(root = Group.root) = new(root).check!

    def initialize(root)
      @root = root
    end

    def check!
      assert_phone_categories
      assert_sections
      assert_abonnemente
      assert_root_person
    end

    private

    def assert_phone_categories
      existing = ContactAccountCategory.for(PhoneNumber.sti_name, ::Person.sti_name).pluck(:key)
      missing = Mappings::PHONE_CATEGORIES - existing
      raise Error, "Telefonkategorien nicht gefunden: #{missing.join(", ")}" if missing.any?
    end

    def assert_sections
      names = Mappings::SECTIONS.values.uniq
      missing = names - Group::Sektion.where(name: names).pluck(:name)
      raise Error, "Sektionen nicht gefunden: #{missing.join(", ")}" if missing.any?
    end

    def assert_abonnemente
      return if @root.children.exists?(type: Group::DachverbandAbonnemente.sti_name)

      raise Error, "Gruppe Abonnemente unter #{@root} nicht gefunden"
    end

    def assert_root_person
      raise Error, "Root-User #{Settings.root_email} nicht gefunden" unless ::Person.root
    end
  end
end
