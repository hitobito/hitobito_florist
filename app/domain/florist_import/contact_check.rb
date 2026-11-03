# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  class ContactCheck
    attr_reader :attributes, :private_phone, :duplicate_email, :notes, :hints

    def initialize(row, email_taken:)
      @attributes = row.person_attributes.dup
      @private_phone = row.private_phone
      @notes = []
      @hints = []
      @tags = row.tags.dup
      check_phones
      check_emails
      @tags << Mappings::INVALID_DATA_TAG if @notes.any?
      check_duplicate_email if email_taken
      check_canton
      check_zip_code
      @attributes["tags"] = @tags.join(", ") if @tags.any?
    end

    private

    def check_phones
      Mappings::CHECKED_PHONES.each do |column, key|
        value = @attributes[key]
        next if value.nil? || valid_phone?(value)

        @attributes.delete(key)
        invalid(column, value)
      end
      return if @private_phone.nil? || valid_phone?(@private_phone)

      invalid("Telefon Pr", @private_phone)
      @private_phone = nil
    end

    def check_emails
      Mappings::CHECKED_EMAILS.each do |column, key|
        value = @attributes[key]
        next if value.nil? || valid_email?(value, main: key == "email")

        @attributes.delete(key)
        invalid(column, value)
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
      @notes << "Ungültige PLZ: #{zip_code}"
      @hints << "Postleitza '#{zip_code}' ist ungültig und wurde nicht übernommen"
    end

    def invalid(column, value)
      @notes << "Ungültige #{Mappings::INVALID_NOTE_FIELDS.fetch(column)}: #{value}"
      @hints << "#{column} '#{value}' ist ungültig und wurde nicht übernommen"
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
