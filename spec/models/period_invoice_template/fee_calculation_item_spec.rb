# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"

describe PeriodInvoiceTemplate::FeeCalculationItem do
  let(:root) { groups(:root) }
  let(:aargau) { groups(:aargau) }

  let(:template) do
    Fabricate(:florist_period_invoice_template, group: root,
      start_on: Date.new(2026, 1, 1), end_on: Date.new(2026, 12, 31))
  end

  subject(:item) { template.items.first }

  let(:generated) { item.to_invoice_item_for_people(recipient_people: Person.all) }

  def generated_named(key, **interpolations)
    name = I18n.t(key, scope: "florist.membership_fee_items", **interpolations)
    generated.find { |i| i.name == name }
  end

  it "is offered on the period invoice template form" do
    expect(Settings.groups.period_invoice_templates.enabled).to eq true
    expect(Settings.groups.period_invoice_templates.item_classes.to_h.keys.map(&:to_s))
      .to include("PeriodInvoiceTemplate::FeeCalculationItem")
  end

  it "is labelled Mitgliedschaftsbeiträge" do
    expect(described_class.model_name.human).to eq "Mitgliedschaftsbeiträge"
  end

  it "cannot be used for invoices addressed to groups" do
    expect { item.to_invoice_item_for_groups }.to raise_error(/only sends membership fee invoices/)
  end

  describe "#to_invoice_item_for_people" do
    it "generates the items of the umbrella organisation and of every invoiced section" do
      # 20 items of the Dachverband, plus the items with a non zero unit cost of the six
      # sections which do not invoice their members themselves
      expect(generated.size).to eq 66
    end

    it "passes the period of the template to every item" do
      expect(generated.map(&:period_start_on).uniq).to eq [Date.new(2026, 1, 1)]
      expect(generated.map(&:period_end_on).uniq).to eq [Date.new(2026, 12, 31)]
      expect(generated.map(&:template_item_id).uniq).to eq [item.id]
    end

    it "builds the configured item classes" do
      expect(generated.map(&:class).uniq.map(&:name)).to contain_exactly(
        "Invoice::EmployeeCountConditionalItem",
        "Invoice::FieldSumItem",
        "Invoice::FilterCountItem"
      )
    end

    describe "items of the umbrella organisation" do
      subject(:base_fee) { generated_named(:base_fee_aktivmitglied_max_2_employees) }

      it "carries the fixed unit cost, account and cost center" do
        expect(base_fee).to be_an_instance_of(Invoice::EmployeeCountConditionalItem)
        expect(base_fee.unit_cost).to eq 440
        expect(base_fee.account).to eq "3001"
        expect(base_fee.cost_center).to eq "310"
        expect(base_fee.min_employees).to eq 2
        expect(base_fee.max_employees).to eq 2
      end

      it "carries the vat rate of the subscription" do
        expect(generated_named(:subscription_florist).vat_rate).to eq 2.6
      end

      it "keeps credits negative" do
        expect(generated_named(:credit_per_apprentice).unit_cost).to eq(-60)
        expect(generated_named(:credit_gv_dachverband).unit_cost).to eq(-100)
      end

      it "is not restricted to a section" do
        expect(base_fee.section_id).to be_nil
      end
    end

    describe "items of a section" do
      subject(:base_fee) do
        generated_named(:section_base_fee_aktivmitglied, section: aargau.name)
      end

      it "names the section and carries its unit cost and account" do
        expect(base_fee.name).to eq "Fixe Grundtaxe Aktivmitglieder Sektion Aargau"
        expect(base_fee.unit_cost).to eq 200
        expect(base_fee.account).to eq "2291"
        expect(base_fee.section_id).to eq aargau.id
      end

      it "keeps the credit of the section negative" do
        credit = generated_named(:section_credit_gv_sektion, section: aargau.name)
        expect(credit.unit_cost).to eq(-100)
      end

      it "charges the advertising fee only in sections which collect one" do
        advertising = generated_named(:section_advertising_fee, section: "Zürich")
        expect(advertising.unit_cost).to eq 60
        expect(advertising.account).to eq "2296"
        expect(generated_named(:section_advertising_fee, section: aargau.name)).to be_nil
      end

      it "skips amounts the section does not charge" do
        expect(generated_named(:section_fee_per_branch, section: "Mittelland/Wallis")).to be_nil
        expect(groups(:mittelland_wallis).section_branch_fee).to eq 0
      end

      it "skips the sections which invoice their members themselves" do
        [groups(:nordwestschweiz), groups(:zentralschweiz)].each do |section|
          expect(generated.map(&:name)).not_to include(/#{section.name}/)
          expect(generated.map(&:section_id)).not_to include(section.id)
        end
      end
    end

    describe "translations" do
      it "fills the name for every language, because only the recipient's one is copied" do
        expect(generated_named(:credit_per_apprentice).name_de).to eq "Gutschrift pro Lernende"
        expect(generated_named(:credit_per_apprentice).name_fr).to be_present
        expect(generated_named(:credit_per_apprentice).name_it).to be_present
      end
    end
  end
end
