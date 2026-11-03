# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

module FloristImport
  module Mappings
    MEMBER_ROLES = {
      "A" => Group::Sektion::Aktivmitglied,
      "R" => Group::Sektion::Aktivmitglied,
      "Q" => Group::Sektion::Aktivmitglied,
      "B" => Group::Sektion::Berufsmitglied,
      "C" => Group::Sektion::Berufsmitgliedplus,
      "D" => Group::Sektion::StartUp,
      "E" => Group::Sektion::Ehrenmitglied,
      "F" => Group::Sektion::Filiale,
      "H" => Group::Sektion::Entdecker,
      "L" => Group::Sektion::Partnermitglied,
      "P" => Group::Sektion::Passivmitglied
    }.freeze

    EX_MEMBER_CODE = "X"
    INTERESTED_CODE = "I"

    # TBD: these codes skip the row even if further codes are set
    SKIP_CODES = {
      "V" => "Verstorben",
      "U" => "Ungültig",
      "G" => "Übersprungen"
    }.freeze

    IGNORED_MEMBER_CODES = %w[N].freeze

    CONTACT_ROLE = Group::DachverbandKontakte::Kontakt
    CONTACT_GROUPS = {
      interessenten: "Interessenten",
      ex_mitglieder: "Ex Mitglieder",
      import_datenmigration: "Import Datenmigration"
    }.freeze

    ABO_ROLES = {
      "1" => Group::DachverbandAbonnemente::JahresaboSchweiz,
      "2" => Group::DachverbandAbonnemente::JahresaboMitglied,
      "3" => Group::DachverbandAbonnemente::JahresaboEuropa,
      "5" => Group::DachverbandAbonnemente::Probeabo,
      "6" => Group::DachverbandAbonnemente::Lehrlingsabo,
      "7" => Group::DachverbandAbonnemente::Gratisabo,
      "8" => Group::DachverbandAbonnemente::LehrgangFloristik,
      "9" => Group::DachverbandAbonnemente::BMplus
    }.freeze

    IGNORED_ABO_CODES = {
      "4" => "Jahresabo Jungfloristen"
    }.freeze

    SECTIONS = {
      "1" => "Aargau",
      "2" => "Nordwestschweiz",
      "3" => "Mittelland/Wallis",
      "4" => "Zentralschweiz",
      "5" => "Ostschweiz",
      "6" => "Zürich",
      "7" => "Ticino",
      "8" => "Suisse Romande"
    }.freeze

    # "GV Besuch" => [visited_gv_dachverband, visited_gv_sektion]
    GV_VISITS = {
      "0" => [false, false],
      "1" => [true, false],
      "2" => [false, true],
      "3" => [true, true]
    }.freeze

    GENDERS = {
      "herr" => "m",
      "frau" => "w",
      "madame" => "w",
      "rechtsanwältin" => "w"
    }.freeze

    COMPANY_SALUTATION = "firma"

    # TBD: provisional until the new phone number categories are defined
    PRIVATE_PHONE_CATEGORY = "other"
    PRIVATE_PHONE_LABEL = "Privat"

    INVALID_DATA_TAG = "import:data-invalid"
    MISSING_SECTION_TAG = "import:missing-section"
    INVALID_ZIP_TAG = "import:invalid-plz"
    DUPLICATE_EMAIL_CATEGORY = "other"
    DUPLICATE_EMAIL_LABEL = "Duplikat"

    CHECKED_PHONES = {
      "Telefon Ge" => "phone_number_work",
      "Mobilnumme" => "phone_number_mobile"
    }.freeze

    CHECKED_EMAILS = {
      "Email-Adre" => "email",
      "E-Mail RG" => "additional_email_invoices",
      "Zusatz Ema" => "additional_email_private"
    }.freeze

    INVALID_NOTE_FIELDS = {
      "Telefon Ge" => "Telefonnummer Geschäft",
      "Mobilnumme" => "Telefonnummer Mobil",
      "Telefon Pr" => "Telefonnummer Privat",
      "Email-Adre" => "Email",
      "E-Mail RG" => "E-Mail RG",
      "Zusatz Ema" => "Zusatz Email"
    }.freeze

    NOTE_COLUMNS = ["Zusatzfeld", "Zusatzfeld.1", "Zusatzfeld.2"].freeze

    MUTATION_NOTE_PREFIX = "Mutationsdatum: "

    QUALIFICATION_COLUMNS = [
      "QV-Chefexpertin", "QV-Expertin", "üK-Expertin", "üK-Chefexpertin",
      "BP-Chefexpertin", "BP-Expertin", "BP-Prüfkommiss.", "SKBEQ", "Berufsfachschule",
      "Berufsschul-Lehrpersonen", "Kursleiterin", "Vorkursanbieter", "externe Kursanbieter"
    ].freeze

    UNSET_VALUES = %w[0 nein false].freeze

    DATE_FORMAT = "%Y-%m-%d"
    DATE_FORMAT_LABEL = "JJJJ-MM-TT"

    LANGUAGES = {
      "1" => "de",
      "2" => "fr"
    }.freeze

    REQUIRED_HEADERS = ([
      "Adressnumm", "Anrede", "Firma", "Name", "Vorname", "Code 3 Abo", "Code 4 Mit",
      "Abteilung/", "Strasse/Nu", "Postleitza", "Ortschaft", "Land", "Telefon Ge", "Telefon Pr",
      "Mobilnumme", "Hausnummer", "Postfach", "Eintrittsd", "Austrittsd", "Geburtstag",
      "Zusatz Ema", "Anzahl Fil", "Adresszusa", "Email-Adre", "Homepage", "Kanton", "E-Mail RG",
      "Anzahl Vol", "Anzahl Tei", "Anzahl Aus", "GV Besuch", "Abo Beginn", "Abo Ende",
      "Sektionszu", "Sprachcode", "Mutationsd"
    ] + NOTE_COLUMNS + QUALIFICATION_COLUMNS).freeze
  end
end
