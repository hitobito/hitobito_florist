# frozen_string_literal: true

#  Copyright (c) 2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require "spec_helper"

describe PeriodInvoiceTemplatesController do
  render_views

  let(:root) { groups(:root) }

  before { sign_in(people(:admin)) }

  it "offers the membership fee item on the form, without inputs for its amounts" do
    get :new, params: {group_id: root.id, recipient_source_type: "PeopleFilter"}

    expect(response.body).to include "Mitgliedschaftsbeiträge"
  end

  it "creates a template with the membership fee item" do
    expect do
      post :create, params: {
        group_id: root.id,
        period_invoice_template: {
          name: "Jahresrechnung 2026",
          start_on: "01.01.2026",
          end_on: "31.12.2026",
          recipient_source_attributes: {type: "PeopleFilter"},
          items_attributes: {
            "0" => {
              type: "PeriodInvoiceTemplate::FeeCalculationItem",
              name: "Mitgliedschaftsbeiträge",
              dynamic_cost_parameters: {unit_cost: "0"}
            }
          }
        }
      }
    end.to change { PeriodInvoiceTemplate.count }.by(1)

    template = PeriodInvoiceTemplate.last
    expect(template.items.map(&:class)).to eq [PeriodInvoiceTemplate::FeeCalculationItem]
    expect(template.recipient_source).to be_a PeopleFilter
  end

  it "does not offer period invoice templates addressed to groups" do
    expect(root.decorate.show_new_period_invoice_template_for_groups?).to eq false
  end
end
