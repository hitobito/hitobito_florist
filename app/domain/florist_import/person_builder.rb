# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  class PersonBuilder
    QUALIFICATION_ORIGIN = "Datenmigration"

    def initialize(groups)
      @groups = groups
      @qualification_kinds = {}
    end

    def qualification_kinds(row)
      row.qualification_labels.map { |label| qualification_kind(label) }
    end

    def build(checked, kinds)
      ::Person.new.tap do |person|
        Import::Person.new(person, checked.attributes.dup, override: true, can_manage_tags: true)
          .populate
        build_websites(person, checked)
        build_duplicate_email(person, checked)
        build_roles(person, checked)
        build_qualifications(person, kinds)
        build_notes(person, checked.person_notes)
      end
    end

    def error_messages(person)
      nested = (person.roles + person.qualifications).flat_map do |record|
        record.errors.full_messages.map { |message| "#{record.class.model_name.human}: #{message}" }
      end
      own = person.errors.reject { |error| [:roles, :qualifications].include?(error.attribute) }
      own.map(&:full_message) + nested
    end

    private

    def build_websites(person, checked)
      checked.websites.each do |name|
        person.social_accounts.build(name:, category_id: website_category&.id)
      end
    end

    def build_roles(person, checked)
      checked.roles.each do |role|
        group = @groups.fetch(role[:group], section_code: checked.section_code)
        person.roles << role[:type].new(group:, start_on: role[:start_on], end_on: role[:end_on])
      end
    end

    def build_duplicate_email(person, checked)
      return unless checked.duplicate_email

      person.additional_emails.build(
        email: checked.duplicate_email,
        category_id: duplicate_email_category&.id,
        label: Mappings::DUPLICATE_EMAIL_LABEL
      )
    end

    def build_notes(person, texts)
      texts.each { |text| person.notes.build(text:, author: root_person) }
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

    def root_person = @root_person ||= ::Person.root

    def website_category
      @website_category ||= ContactAccountCategory
        .for(SocialAccount.sti_name, ::Person.sti_name)
        .find_by(key: "website")
    end

    def duplicate_email_category
      @duplicate_email_category ||= ContactAccountCategory
        .for(AdditionalEmail.sti_name, ::Person.sti_name)
        .find_by(key: Mappings::DUPLICATE_EMAIL_CATEGORY)
    end
  end
end
