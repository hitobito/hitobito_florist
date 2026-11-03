# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  class Row
    include Mappings
    include Values

    UNSET_CODE = "_"

    attr_reader :line

    def initialize(csv_row, line:, groups:)
      @csv_row = csv_row
      @line = line
      @groups = groups
      @errors = []
      @notes = []
    end

    def errors
      person_attributes
      roles
      @errors
    end

    def notes
      roles
      @notes
    end

    def tags
      roles
      @missing_section ? [MISSING_SECTION_TAG] : []
    end

    def id
      return @id if defined?(@id)

      @id = integer("Adressnumm", required: true)
    end

    def email = value("Email-Adre")&.downcase

    def skip_reason
      code = member_codes.find { |c| SKIP_CODES.key?(c) }
      "#{SKIP_CODES[code]} (Code 4 Mit '#{code}')" if code
    end

    def mutation_note
      "#{MUTATION_NOTE_PREFIX}#{value("Mutationsd")}" if value("Mutationsd")
    end

    def address_number = value("Adressnumm")

    def first_name = value("Vorname")

    def last_name = value("Name")

    def person_attributes
      @person_attributes ||= {
        "id" => id,
        "email" => email,
        "birthday" => date("Geburtstag"),
        "language" => language,
        "additional_information" => notes_text
      }.merge(name_attributes, address_attributes, florist_attributes, contact_attributes).compact
    end

    def additional_websites
      (website_from_additional_email && value("Homepage")) ? [website_from_additional_email] : []
    end

    def private_phone = value("Telefon Pr")

    def roles = @roles ||= member_roles + abo_roles

    def qualification_labels
      QUALIFICATION_COLUMNS.select { |column| set?(value(column)) }
    end

    private

    def name_attributes
      {
        "first_name" => value("Vorname"),
        "last_name" => value("Name"),
        "company_name" => value("Firma"),
        "company" => company?,
        "gender" => GENDERS[value("Anrede")&.downcase]
      }
    end

    def address_attributes
      {
        "street" => value("Strasse/Nu"),
        "housenumber" => value("Hausnummer"),
        "postbox" => value("Postfach"),
        "zip_code" => value("Postleitza"),
        "town" => value("Ortschaft"),
        "country" => value("Land"),
        "canton" => value("Kanton")&.downcase,
        "address_care_of" => care_of
      }
    end

    def florist_attributes
      dachverband, sektion = gv_visits
      {
        "full_time_employee_count" => integer("Anzahl Vol"),
        "part_time_employee_count" => integer("Anzahl Tei"),
        "apprentice_count" => integer("Anzahl Aus"),
        "branch_count" => integer("Anzahl Fil"),
        "visited_gv_dachverband" => dachverband,
        "visited_gv_sektion" => sektion
      }
    end

    def contact_attributes
      {
        "phone_number_work" => value("Telefon Ge"),
        "phone_number_mobile" => value("Mobilnumme"),
        "additional_email_invoices" => value("E-Mail RG"),
        "additional_email_private" => additional_email,
        "social_account_website" => value("Homepage") || website_from_additional_email
      }
    end

    def company?
      value("Firma").present? || value("Anrede")&.downcase == COMPANY_SALUTATION
    end

    def care_of = [value("Abteilung/"), value("Adresszusa")].compact.join(", ").presence

    def gv_visits
      visit = integer_code("GV Besuch")
      return [false, false] if visit.nil?

      GV_VISITS.fetch(visit) do
        @errors << "GV Besuch '#{visit}' ist nicht zugeordnet"
        [false, false]
      end
    end

    def language
      code = integer_code("Sprachcode")
      return if code.nil?

      LANGUAGES.fetch(code) do
        @errors << "Sprachcode '#{code}' ist nicht zugeordnet"
        nil
      end
    end

    def notes_text
      NOTE_COLUMNS.filter_map { |column| value(column) }.join("\n").presence
    end

    def additional_email
      value("Zusatz Ema") if value("Zusatz Ema")&.include?("@")
    end

    def website_from_additional_email
      value("Zusatz Ema") unless value("Zusatz Ema")&.include?("@")
    end

    def member_roles
      return [] if skip_reason

      codes = member_codes - IGNORED_MEMBER_CODES
      contact_roles(codes) + section_roles(codes - [INTERESTED_CODE, EX_MEMBER_CODE])
    end

    # TBD: with X and section codes, the section roles end at Austrittsd and Ex Mitglieder starts
    # the day after
    def contact_roles(codes)
      roles = []
      if codes.include?(INTERESTED_CODE)
        roles << role(@groups.interessenten, CONTACT_ROLE, Time.zone.today, nil)
      end
      if codes.include?(EX_MEMBER_CODE)
        roles << role(@groups.ex_mitglieder, CONTACT_ROLE, ex_member_start, nil)
      end
      roles
    end

    def ex_member_start = date("Austrittsd")&.next_day || Time.zone.today

    def section_roles(codes)
      unknown = codes - MEMBER_ROLES.keys
      unknown.each { |code| role_error("Code 4 Mit '#{code}' ist unbekannt") }
      types = (codes - unknown).map { |code| MEMBER_ROLES[code] }.uniq
      return [] if types.empty?

      section = @groups.sections[integer_code("Sektionszu")]
      unless section
        @missing_section = true
        @notes << "Sektionszu '#{value("Sektionszu")}' ist nicht zugeordnet, " \
          "ohne Mitgliederrolle importiert"
        return []
      end

      types.map { |type| role(section, type, date("Eintrittsd"), date("Austrittsd")) }
    end

    def abo_roles
      abo_codes.filter_map do |code|
        if ABO_ROLES.key?(code)
          role(@groups.abonnemente, ABO_ROLES[code], date("Abo Beginn"), date("Abo Ende"))
        elsif IGNORED_ABO_CODES.key?(code)
          @notes << "Abo-Code #{code} (#{IGNORED_ABO_CODES[code]}) nicht importiert"
          nil
        else
          role_error("Code 3 Abo '#{code}' ist unbekannt")
        end
      end
    end

    def role(group, type, start_on, end_on)
      {group: group, type: type, start_on: start_on, end_on: end_on}
    end

    def role_error(message)
      @errors << message
      nil
    end

    def member_codes = codes("Code 4 Mit")

    def abo_codes = codes("Code 3 Abo")

    def codes(column) = value(column).to_s.upcase.delete(UNSET_CODE).chars.uniq
  end
end
