# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  class Groups
    attr_reader :sections, :abonnemente, :contact_groups, :created_groups, :root_person

    class << self
      def resolve(root = Group.root)
        sections = resolve_sections
        abonnemente = find_abonnemente(root)
        root_person = find_root_person
        created = []
        contact_groups = Mappings::CONTACT_GROUPS.transform_values do |name|
          find_contact_group(root, name) || create_contact_group(root, name).tap { created << _1 }
        end

        new(sections:, abonnemente:, contact_groups:, created_groups: created, root_person:)
      end

      private

      def resolve_sections
        groups = Group::Sektion.where(name: Mappings::SECTIONS.values.uniq).index_by(&:name)
        missing = Mappings::SECTIONS.values.uniq - groups.keys
        raise Error, "Sektionen nicht gefunden: #{missing.join(", ")}" if missing.any?

        Mappings::SECTIONS.transform_values { |name| groups.fetch(name) }
      end

      def find_abonnemente(root)
        root.children.find_by(type: Group::DachverbandAbonnemente.sti_name) ||
          raise(Error, "Gruppe Abonnemente unter #{root} nicht gefunden")
      end

      def find_root_person
        ::Person.root || raise(Error, "Root-User #{Settings.root_email} nicht gefunden")
      end

      def find_contact_group(root, name)
        Group::DachverbandKontakte.find_by(parent_id: root.id, name:)
      end

      def create_contact_group(root, name)
        Group::DachverbandKontakte.create!(parent: root, name:)
      end
    end

    def initialize(sections:, abonnemente:, contact_groups:, created_groups: [], root_person: nil)
      @sections = sections
      @abonnemente = abonnemente
      @contact_groups = contact_groups
      @created_groups = created_groups
      @root_person = root_person
    end

    def interessenten = contact_groups.fetch(:interessenten)

    def ex_mitglieder = contact_groups.fetch(:ex_mitglieder)

    def import_datenmigration = contact_groups.fetch(:import_datenmigration)
  end
end
