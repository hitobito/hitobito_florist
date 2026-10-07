# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"

describe Invoice::BatchCreate do
  let(:root) { groups(:root) }
  let(:aargau) { groups(:aargau) }
  let(:zentralschweiz) { groups(:zentralschweiz) }
  let(:admin) { people(:admin) }

  let(:period_start_on) { Date.new(2026, 1, 1) }
  let(:period_end_on) { Date.new(2026, 12, 31) }

  let(:template) do
    Fabricate(:florist_period_invoice_template, group: root,
      start_on: period_start_on, end_on: period_end_on)
  end

  let(:invoice_run) do
    InvoiceRun.new(group: root, title: "Jahresrechnung 2026", creator: admin,
      period_invoice_template: template,
      recipient_source: template.recipient_source).tap do |run|
      run.invoice = Invoice.new(group: root, title: run.title)
      run.invoice.invoice_items = template.items.flat_map do |item|
        item.to_invoice_item_for_people(recipient_people: Person.all.select(:id))
      end
    end
  end

  def member(group, role = Group::Sektion::Aktivmitglied, **person_attrs)
    person = Fabricate(:person, street: "Musterweg", housenumber: "1",
      zip_code: "3000", town: "Bern", **person_attrs)
    Fabricate(role.sti_name, group: group, person: person,
      start_on: period_start_on - 1.year, end_on: period_end_on + 1.year)
    person
  end

  def create_invoices
    invoice_run.save!
    described_class.new(invoice_run, admin).call
    invoice_run.reload
  end

  def items_of(person)
    invoice_run.invoices.find_by(recipient: person).invoice_items
  end

  context "an Aktivmitglied of Aargau" do
    let!(:person) do
      member(aargau, full_time_employees: 2, part_time_employees: 1, apprentices: 1,
        branches: 1, visited_gv_dachverband: true, visited_gv_sektion: true)
    end

    before { create_invoices }

    it "is charged the fees of the umbrella organisation and of its section" do
      expect(items_of(person).map { |i| [i.name, i.count, i.unit_cost, i.cost] })
        .to contain_exactly(
          # Dachverband, three employees in total
          ["Fixe Grundtaxe Aktivmitglieder (inkl. Geschäftsinhaber) 3 und mehr Mitarbeiter",
            1, 540, 540],
          ["PR-Beitrag fixe Grundtaxe Aktivmitglieder 3 und mehr Mitarbeiter", 1, 40.5, 40.5],
          ["Beitrag pro Angestellte 80 - 100 %", 2, 130, 260],
          ["PR-Beitrag Angestellte", 2, 9.75, 19.5],
          ["Beitrag pro Teilzeitangestellte 10 - 79 %", 1, 72, 72],
          ["PR-Beitrag Teilzeitangestellte", 1, 5.4, 5.4],
          ["Beitrag pro Filialbetrieb", 1, 150, 150],
          ["PR-Beitrag Filialbetriebe", 1, 11.25, 11.25],
          ["Abo Florist (integraler Bestandteil der Aktivmitgliedschaft)", 1, 115, 115],
          ["Gutschrift pro Lernende", 1, -60, -60],
          ["Gutschrift Besuch Generalversammlung florist.ch", 1, -100, -100],
          # Sektion Aargau
          ["Fixe Grundtaxe Aktivmitglieder Sektion Aargau", 1, 200, 200],
          ["Beitrag pro Angestellte 80 - 100 % Sektion Aargau", 2, 50, 100],
          ["Beitrag pro Teilzeitangestellte 10 - 79 % Sektion Aargau", 1, 25, 25],
          ["Beitrag pro Filialbetrieb Sektion Aargau", 1, 50, 50],
          ["Gutschrift Besuch Generalversammlung Sektion Aargau", 1, -100, -100]
        )
    end

    it "books the section items onto the account of the section" do
      section_item = items_of(person).find { |i| i.name.end_with?("Sektion Aargau") }
      expect(section_item.account).to eq aargau.section_fee_account
    end

    it "does not contain the items of the other sections" do
      expect(items_of(person).map(&:name).grep(/Sektion Z/)).to be_empty
    end
  end

  context "an Aktivmitglied without employees who attended no general assembly" do
    let!(:person) { member(aargau) }

    before { create_invoices }

    it "is only charged the items which are not zero" do
      expect(items_of(person).map(&:name)).to contain_exactly(
        "Fixe Grundtaxe Aktivmitglieder (inkl. Geschäftsinhaber) bis 1 Mitarbeiter",
        "PR-Beitrag fixe Grundtaxe Aktivmitglieder bis 1 Mitarbeiter",
        "Abo Florist (integraler Bestandteil der Aktivmitgliedschaft)",
        "Fixe Grundtaxe Aktivmitglieder Sektion Aargau"
      )
    end
  end

  context "a Berufsmitglied plus" do
    let!(:person) { member(aargau, Group::Sektion::Berufsmitgliedplus) }

    before { create_invoices }

    it "is charged the base fee and the specialist magazine only" do
      expect(items_of(person).map { |i| [i.name, i.cost] }).to contain_exactly(
        ["Fixe Grundtaxe Berufsmitglieder plus", 50],
        ["Abo Fachmagazin Floristen", 77.95],
        ["Fixe Grundtaxe Berufsmitglieder Sektion Aargau", 50]
      )
    end
  end

  context "a second invoice run over the same period" do
    let!(:person) { member(aargau, full_time_employees: 2, visited_gv_sektion: true) }

    before { create_invoices }

    it "records every charged item as a processed subject" do
      expect(InvoiceRun::ProcessedSubject.where(subject_id: person.id).count)
        .to eq items_of(person).count
    end

    it "does not charge the member again" do
      run = InvoiceRun.new(group: root, title: "Nachlauf 2026", creator: admin,
        period_invoice_template: template,
        recipient_source: template.recipient_source)
      run.invoice = Invoice.new(group: root, title: run.title)
      run.invoice.invoice_items = template.items.flat_map do |item|
        item.to_invoice_item_for_people(recipient_people: Person.all.select(:id))
      end
      run.save!

      expect { described_class.new(run, admin).call }
        .to not_change { Invoice.count }
      expect(run.reload.invoices).to be_empty
    end
  end

  context "a role which is not invoiced" do
    let!(:person) { member(aargau, Group::Sektion::Ehrenmitglied) }

    before { create_invoices }

    it "receives no invoice" do
      expect(invoice_run.invoices.find_by(recipient: person)).to be_nil
    end
  end

  context "a member of a section invoicing its members itself" do
    let!(:person) { member(zentralschweiz, full_time_employees: 5) }

    before { create_invoices }

    it "receives no invoice at all, not even for the umbrella organisation" do
      expect(invoice_run.invoices.find_by(recipient: person)).to be_nil
    end
  end

  context "a member joining during the period" do
    let!(:person) do
      Fabricate(:person, street: "Musterweg", housenumber: "1", zip_code: "3000",
        town: "Bern").tap do |p|
        Fabricate(Group::Sektion::Aktivmitglied.sti_name, group: aargau, person: p,
          start_on: period_start_on + 1.month, end_on: period_end_on + 1.year)
      end
    end

    before { create_invoices }

    it "is invoiced manually instead, so receives no invoice" do
      expect(invoice_run.invoices.find_by(recipient: person)).to be_nil
    end
  end
end
