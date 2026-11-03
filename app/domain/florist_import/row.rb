# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  class Row
    include Mappings

    INTEGER_FORMAT = /\A\d+(\.0+)?\z/
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

    def id
      return @id if defined?(@id)

      @id = integer("Adressnumm", required: true)
    end

    def email = value("Email-Adre")&.downcase

    # TBD: V skips the row even if further codes are set
    def deceased? = member_codes.include?(DECEASED_CODE)

    def name
      [value("Vorname"), value("Name")].compact.join(" ").presence || value("Firma")
    end

    def raw = @csv_row.to_csv.chomp

    def person_attributes
      @person_attributes ||= {
        "id" => id,
        "email" => email,
        "birthday" => date("Geburtstag"),
        "language" => value("Sprachcode")&.downcase,
        "additional_information" => notes_text
      }.merge(name_attributes, address_attributes, florist_attributes, contact_attributes).compact
    end

    def additional_websites
      (website_from_additional_email && value("Homepage")) ? [website_from_additional_email] : []
    end

    def private_phone = value("Telefon Pr")

    def roles = @roles ||= (member_roles + abo_roles).tap { |roles| assert_any(roles) }

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

    def care_of
      department = value("Abteilung/")
      addition = value("Adresszusa")
      if department && addition
        @errors << "c/o-Feld ist bereits durch Abteilung/ '#{department}' belegt, " \
          "Adresszusa '#{addition}' kann nicht übernommen werden"
      end
      department || addition
    end

    def gv_visits
      visit = integer_code("GV Besuch")
      return [false, false] if visit.nil?

      GV_VISITS.fetch(visit) do
        @errors << "GV Besuch '#{visit}' ist nicht zugeordnet"
        [false, false]
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
      return [] if deceased?

      interested = [role(@groups.interessenten, INTERESTED_ROLE, Time.zone.today, nil)]
      (member_codes.include?(INTERESTED_CODE) ? interested : []) +
        section_roles(member_codes - [INTERESTED_CODE])
    end

    def section_roles(codes)
      unknown = codes - MEMBER_ROLES.keys
      unknown.each { |code| role_error("Code 4 Mit '#{code}' ist unbekannt") }
      types = (codes - unknown).map { |code| MEMBER_ROLES[code] }.uniq
      return [] if types.empty?

      section = @groups.sections[integer_code("Sektionszu")]
      unless section
        role_error("Sektionszu '#{value("Sektionszu")}' ist nicht zugeordnet")
        return []
      end

      types.map { |type| role(section, type, *member_dates(type)) }
    end

    # TBD: with X and further codes, the further roles end and Ex Mitglied starts at Austrittsd
    def member_dates(type)
      if type == MEMBER_ROLES[EX_MEMBER_CODE]
        [date("Austrittsd") || date("Eintrittsd"), nil]
      else
        [date("Eintrittsd"), date("Austrittsd")]
      end
    end

    def abo_roles
      abo_codes.filter_map do |code|
        if ABO_ROLES.key?(code)
          role(@groups.abonnemente, ABO_ROLES[code], date("Abo Beginn"), date("Abo Ende"))
        elsif IGNORED_ABO_CODES.key?(code)
          @notes << "Abo-Code #{code} (#{IGNORED_ABO_CODES[code]}) nicht importiert"
          nil
        else
          role_error("Code 3 ABo '#{code}' ist unbekannt")
        end
      end
    end

    def role(group, type, start_on, end_on)
      {group: group, type: type, start_on: start_on, end_on: end_on}
    end

    def assert_any(roles)
      return if roles.any? || @role_error

      @errors << "Keine Rolle: Code 4 Mit und Code 3 ABo ergeben keine importierbare Rolle"
    end

    def role_error(message)
      @role_error = true
      @errors << message
      nil
    end

    def member_codes = codes("Code 4 Mit")

    def abo_codes = codes("Code 3 ABo")

    def codes(column) = value(column).to_s.upcase.delete(UNSET_CODE).chars.uniq

    def integer_code(column)
      raw = value(column)
      raw&.match?(INTEGER_FORMAT) ? raw.to_i.to_s : raw
    end

    def integer(column, required: false)
      raw = value(column)
      return raw.to_i if raw&.match?(INTEGER_FORMAT)

      if raw
        @errors << "#{column} '#{raw}' ist keine ganze Zahl"
      elsif required
        @errors << "#{column} fehlt"
      end
      required ? nil : 0
    end

    def date(column)
      @dates ||= {}
      return @dates[column] if @dates.key?(column)

      @dates[column] = parse_date(column)
    end

    def parse_date(column)
      raw = value(column)
      return if raw.nil?

      Date.strptime(raw, DATE_FORMAT)
    rescue Date::Error
      @errors << "#{column} '#{raw}' ist kein Datum im Format TT.MM.JJJJ"
      nil
    end

    def set?(raw) = raw.present? && UNSET_VALUES.exclude?(raw.downcase)

    def value(column) = @csv_row[column]&.strip.presence
  end
end
