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
      "P" => Group::Sektion::Passivmitglied,
      "X" => Group::Sektion::ExMitglied
    }.freeze

    EX_MEMBER_CODE = "X"
    INTERESTED_CODE = "I"
    DECEASED_CODE = "V"

    INTERESTED_ROLE = Group::DachverbandKontakte::Kontakt
    INTERESTED_GROUP_NAME = "Interessenten"

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

    NOTE_COLUMNS = ["TextBox", "Zusatzfeld", "Zusatzfeld.1", "Zusatzfeld.2"].freeze

    QUALIFICATION_COLUMNS = [
      "QV-Chefexpertin", "QV-Expertin", "üK-Expertin", "üK-Chefexpertin",
      "BP-Chefexpertin", "BP-Expertin", "BP-Prüfkommiss.", "SKBEQ", "Berufsfachschule",
      "Berufsschul-Lehrpersonen", "Kursleiterin", "Vorkursanbieter", "externe Kursanbieter"
    ].freeze

    UNSET_VALUES = %w[0 nein false].freeze

    DATE_FORMAT = "%d.%m.%Y"

    REQUIRED_HEADERS = ([
      "Adressnumm", "Anrede", "Firma", "Name", "Vorname", "Code 3 ABo", "Code 4 Mit",
      "Abteilung/", "Strasse/Nu", "Postleitza", "Ortschaft", "Land", "Telefon Ge", "Telefon Pr",
      "Mobilnumme", "Hausnummer", "Postfach", "Eintrittsd", "Austrittsd", "Geburtstag",
      "Zusatz Ema", "Anzahl Fil", "Adresszusa", "Email-Adre", "Homepage", "Kanton", "E-Mail RG",
      "Anzahl Vol", "Anzahl Tei", "Anzahl Aus", "GV Besuch", "Abo Beginn", "Abo Ende",
      "Sektionszu", "Sprachcode"
    ] + NOTE_COLUMNS + QUALIFICATION_COLUMNS).freeze
  end
end
