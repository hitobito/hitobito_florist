# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  class Row
    attr_reader :line, :id, :attributes, :websites, :roles, :errors, :hints, :tags

    def initialize(csv_row, line:)
      @line = line
      @errors = []
      @hints = []
      @tags = []
      @cells = Cells.new(csv_row, errors: @errors)
      @id = @cells.integer("Adressnumm", required: true)
      @attributes = build_attributes
      @websites = [value("Homepage"), website_from_additional_email].compact
      @roles = member_roles + abo_roles + [import_role]
    end

    def email = value("Email-Adre")&.downcase

    def skip_reason
      code = member_codes.find { |c| Mappings::SKIP_CODES.key?(c) }
      "#{Mappings::SKIP_CODES[code]} (Code 4 Mit '#{code}')" if code
    end

    def mutation_note
      "#{Mappings::MUTATION_NOTE_PREFIX}#{value("Mutationsd")}" if value("Mutationsd")
    end

    def address_number = value("Adressnumm")

    def first_name = value("Vorname")

    def last_name = value("Name")

    def section_code = @cells.integer_code("Sektionszu")

    def qualification_labels
      Mappings::QUALIFICATION_COLUMNS.select { |column| @cells.set?(column) }
    end

    private

    def value(column) = @cells.value(column)

    def date(column) = @cells.date(column)

    def build_attributes
      {
        "id" => id,
        "email" => email,
        "birthday" => date("Geburtstag"),
        "language" => language,
        "additional_information" => notes_text
      }.merge(name_attributes, address_attributes, florist_attributes, contact_attributes).compact
    end

    def name_attributes
      {
        "first_name" => value("Vorname"),
        "last_name" => value("Name"),
        "company_name" => value("Firma"),
        "company" => company?,
        "gender" => Mappings::GENDERS[value("Anrede")&.downcase]
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
        "full_time_employee_count" => @cells.integer("Anzahl Vol"),
        "part_time_employee_count" => @cells.integer("Anzahl Tei"),
        "apprentice_count" => @cells.integer("Anzahl Aus"),
        "branch_count" => @cells.integer("Anzahl Fil"),
        "visited_gv_dachverband" => dachverband,
        "visited_gv_sektion" => sektion
      }
    end

    def contact_attributes
      phone_attributes.merge(
        "additional_email_invoices" => value("E-Mail RG"),
        "additional_email_private" => additional_email
      )
    end

    def phone_attributes
      Mappings::CONTACT_FIELDS.select { |_, field| field[:type] == :phone }
        .to_h { |column, _| [Mappings::CONTACT_ATTRIBUTES[column], value(column)] }
    end

    def company?
      value("Firma").present? || value("Anrede")&.downcase == Mappings::COMPANY_SALUTATION
    end

    def care_of = [value("Abteilung/"), value("Adresszusa")].compact.join(", ").presence

    def gv_visits
      visit = @cells.integer_code("GV Besuch")
      return [false, false] if visit.nil?

      Mappings::GV_VISITS.fetch(visit) do
        @errors << "GV Besuch '#{visit}' ist nicht zugeordnet"
        [false, false]
      end
    end

    def language
      code = @cells.integer_code("Sprachcode")
      return if code.nil?

      Mappings::LANGUAGES.fetch(code) do
        @errors << "Sprachcode '#{code}' ist nicht zugeordnet"
        nil
      end
    end

    def notes_text
      Mappings::NOTE_COLUMNS.filter_map { |column| value(column) }.join("\n").presence
    end

    def additional_email
      value("Zusatz Ema") if value("Zusatz Ema")&.include?("@")
    end

    def website_from_additional_email
      value("Zusatz Ema") unless value("Zusatz Ema")&.include?("@")
    end

    def member_roles
      codes = member_codes - Mappings::IGNORED_MEMBER_CODES
      contact_roles(codes) +
        section_roles(codes - [Mappings::INTERESTED_CODE, Mappings::EX_MEMBER_CODE])
    end

    # TBD: with X and section codes, the section roles end at Austrittsd and Ex Mitglieder starts
    # the day after
    def contact_roles(codes)
      roles = []
      if codes.include?(Mappings::INTERESTED_CODE)
        roles << role(:interessenten, Mappings::CONTACT_ROLE, Time.zone.today, nil)
      end
      if codes.include?(Mappings::EX_MEMBER_CODE)
        roles << role(:ex_mitglieder, Mappings::CONTACT_ROLE, ex_member_start, nil)
      end
      roles
    end

    def ex_member_start = date("Austrittsd")&.next_day || Time.zone.today

    def section_roles(codes)
      unknown = codes - Mappings::MEMBER_ROLES.keys
      unknown.each { |code| @errors << "Code 4 Mit '#{code}' ist unbekannt" }
      types = (codes - unknown).map { |code| Mappings::MEMBER_ROLES[code] }.uniq
      return [] if types.empty?
      return missing_section unless Mappings::SECTIONS.key?(section_code)

      types.map { |type| role(:section, type, date("Eintrittsd"), date("Austrittsd")) }
    end

    def missing_section
      @tags << Mappings::MISSING_SECTION_TAG
      @hints << "Sektionszu '#{value("Sektionszu")}' ist nicht zugeordnet, " \
        "ohne Mitgliederrolle importiert"
      []
    end

    def abo_roles
      abo_codes.filter_map do |code|
        if Mappings::ABO_ROLES.key?(code)
          role(:abonnemente, Mappings::ABO_ROLES[code], date("Abo Beginn"), date("Abo Ende"))
        elsif Mappings::IGNORED_ABO_CODES.key?(code)
          @hints << "Abo-Code #{code} (#{Mappings::IGNORED_ABO_CODES[code]}) nicht importiert"
          nil
        else
          @errors << "Code 3 Abo '#{code}' ist unbekannt"
          nil
        end
      end
    end

    def import_role
      role(:import_datenmigration, Mappings::CONTACT_ROLE, Time.zone.today, nil)
    end

    def role(group, type, start_on, end_on)
      {group: group, type: type, start_on: start_on, end_on: end_on}
    end

    def member_codes = @cells.codes("Code 4 Mit")

    def abo_codes = @cells.codes("Code 3 Abo")
  end
end
