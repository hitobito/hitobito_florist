# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  class CheckedRow
    delegate :id, :line, :roles, :websites, :section_code, :qualification_labels, :errors,
      :address_number, :first_name, :last_name, to: :@row

    attr_reader :attributes, :hints, :person_notes, :duplicate_email

    def initialize(row, email_taken:)
      @row = row
      @attributes = row.attributes.dup
      @hints = row.hints.dup
      @person_notes = [row.mutation_note].compact
      @tags = row.tags.dup
      invalid_types = check_contact_fields.uniq
      @tags.concat(Mappings::INVALID_CONTACT_TAGS.values_at(*invalid_types))
      check_duplicate_email if email_taken
      check_canton
      check_zip_code
      @attributes["tags"] = @tags.join(", ") if @tags.any?
    end

    private

    def check_contact_fields
      Mappings::CONTACT_FIELDS.filter_map do |column, field|
        key = Mappings::CONTACT_ATTRIBUTES.fetch(column)
        value = @attributes[key]
        next if value.nil? || valid_contact?(field[:type], value, main: key == "email")

        @attributes.delete(key)
        invalid(column, field[:label], value)
        field[:type]
      end
    end

    def check_duplicate_email
      @duplicate_email = @attributes.delete("email")
      return unless @duplicate_email

      @hints << "Email-Adre #{@duplicate_email} ist bereits vergeben und wurde als zusätzliche " \
        "E-Mail \"#{Mappings::DUPLICATE_EMAIL_LABEL}\" übernommen"
    end

    def check_canton
      canton = @attributes["canton"]
      return if canton.nil? || !Countries.swiss?(@attributes["country"])
      return if Cantons.short_name_strings.include?(canton)

      @attributes.delete("canton")
      @hints << "Kanton '#{canton}' ist ungültig und wurde nicht übernommen"
    end

    def check_zip_code
      zip_code = @attributes["zip_code"]
      return if zip_code.nil? || valid_zip_code?(zip_code)

      @attributes.delete("zip_code")
      @tags << Mappings::INVALID_ZIP_TAG
      @person_notes << "Ungültige PLZ: #{zip_code}"
      @hints << "Postleitza '#{zip_code}' ist ungültig und wurde nicht übernommen"
    end

    def invalid(column, label, value)
      @person_notes << "Ungültige #{label}: #{value}"
      @hints << "#{column} '#{value}' ist ungültig und wurde nicht übernommen"
    end

    def valid_contact?(type, value, main:)
      (type == :phone) ? valid_phone?(value) : valid_email?(value, main:)
    end

    def valid_phone?(number)
      ::PhoneNumber.new(number:).tap(&:validate).errors[:number].empty?
    end

    def valid_zip_code?(zip_code)
      ::Person.new(zip_code:, country: @attributes["country"]).tap(&:validate)
        .errors[:zip_code].empty?
    end

    def valid_email?(email, main:)
      Truemail.valid?(email) && (!main || Devise.email_regexp.match?(email))
    end
  end
end
