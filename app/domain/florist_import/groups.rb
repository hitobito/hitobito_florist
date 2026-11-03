# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  class Groups
    attr_reader :sections, :abonnemente, :interessenten

    class << self
      def resolve(root = Group.root)
        sections = resolve_sections
        abonnemente = find_abonnemente(root)
        interessenten = find_interessenten(root)
        created = interessenten.nil?
        interessenten ||= Group::DachverbandKontakte.create!(
          parent: root, name: Mappings::INTERESTED_GROUP_NAME
        )

        new(sections:, abonnemente:, interessenten:, interessenten_created: created)
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

      def find_interessenten(root)
        Group::DachverbandKontakte.find_by(
          parent_id: root.id, name: Mappings::INTERESTED_GROUP_NAME
        )
      end
    end

    def initialize(sections:, abonnemente:, interessenten:, interessenten_created: false)
      @sections = sections
      @abonnemente = abonnemente
      @interessenten = interessenten
      @interessenten_created = interessenten_created
    end

    def interessenten_created? = @interessenten_created
  end
end
