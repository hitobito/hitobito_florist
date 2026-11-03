# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  class PersonBuilder
    QUALIFICATION_ORIGIN = "Datenmigration"

    def initialize
      @qualification_kinds = {}
    end

    def qualification_kinds(row)
      row.qualification_labels.map { |label| qualification_kind(label) }
    end

    def build(row, kinds, email_taken:)
      attributes = row.person_attributes.dup
      attributes.delete("email") if email_taken
      ::Person.new.tap do |person|
        Import::Person.new(person, attributes, override: true, can_manage_tags: true).populate
        build_websites(person, row)
        build_private_phone(person, row)
        build_roles(person, row)
        build_qualifications(person, kinds)
      end
    end

    def errors(person)
      return [] if person.valid?

      nested = (person.roles + person.qualifications).flat_map do |record|
        record.errors.full_messages.map { |message| "#{record.class.model_name.human}: #{message}" }
      end
      own = person.errors.reject { |error| [:roles, :qualifications].include?(error.attribute) }
      own.map(&:full_message) + nested
    end

    private

    def build_websites(person, row)
      row.additional_websites.each do |name|
        person.social_accounts.build(name:, category_id: website_category&.id)
      end
    end

    def build_private_phone(person, row)
      return unless row.private_phone

      person.phone_numbers.build(
        number: row.private_phone,
        category_id: private_phone_category&.id,
        label: Mappings::PRIVATE_PHONE_LABEL
      )
    end

    def build_roles(person, row)
      row.roles.each do |role|
        person.roles << role[:type].new(
          group: role[:group], start_on: role[:start_on], end_on: role[:end_on]
        )
      end
    end

    def build_qualifications(person, kinds)
      kinds.each do |kind|
        person.qualifications.build(
          qualification_kind: kind,
          start_at: Time.zone.today,
          origin: QUALIFICATION_ORIGIN
        )
      end
    end

    def qualification_kind(label)
      @qualification_kinds[label] ||=
        QualificationKind.joins(:translations)
          .find_by(qualification_kind_translations: {locale: "de", label:}) ||
        I18n.with_locale(:de) { QualificationKind.create!(label:) }
    end

    def website_category
      @website_category ||= ContactAccountCategory
        .for(SocialAccount.sti_name, ::Person.sti_name)
        .find_by(key: "website")
    end

    def private_phone_category
      @private_phone_category ||= ContactAccountCategory
        .for(PhoneNumber.sti_name, ::Person.sti_name)
        .find_by(key: Mappings::PRIVATE_PHONE_CATEGORY)
    end
  end
end
