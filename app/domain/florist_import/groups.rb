# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  class Groups
    attr_reader :sections, :abonnemente, :contact_groups, :created_groups

    class << self
      def resolve(root = Group.root)
        abonnemente = root.children.find_by!(type: Group::DachverbandAbonnemente.sti_name)
        created = []
        contact_groups = Mappings::CONTACT_GROUPS.transform_values do |name|
          find_contact_group(root, name) || create_contact_group(root, name).tap { created << _1 }
        end

        new(sections: resolve_sections, abonnemente:, contact_groups:, created_groups: created)
      end

      private

      def resolve_sections
        groups = Group::Sektion.where(name: Mappings::SECTIONS.values.uniq).index_by(&:name)
        Mappings::SECTIONS.transform_values { |name| groups.fetch(name) }
      end

      def find_contact_group(root, name)
        Group::DachverbandKontakte.find_by(parent_id: root.id, name:)
      end

      def create_contact_group(root, name)
        Group::DachverbandKontakte.create!(parent: root, name:)
      end
    end

    def initialize(sections:, abonnemente:, contact_groups:, created_groups: [])
      @sections = sections
      @abonnemente = abonnemente
      @contact_groups = contact_groups
      @created_groups = created_groups
    end

    def fetch(key, section_code: nil)
      case key
      when :section then sections.fetch(section_code)
      when :abonnemente then abonnemente
      else contact_groups.fetch(key)
      end
    end
  end
end
