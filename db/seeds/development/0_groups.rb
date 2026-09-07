# frozen_string_literal: true

#  Copyright (c) 2012-2026, florist.ch. This file is part of
#  hitobito_florist and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_florist.

require Rails.root.join("db", "seeds", "support", "group_seeder")

seeder = GroupSeeder.new

root = Group.roots.first
srand(42)

if root.address.blank?
  root.update(seeder.group_attributes)
  root.default_children.each do |child_class|
    child_class.first.update(seeder.group_attributes)
  end
end

[
  "Aargau",
  "Nordwestschweiz",
  "Mittelland/Wallis",
  "Zentralschweiz",
  "Ostschweiz",
  "Zürich",
  "Ticino",
  "Suisse Romande"
].each do |name|
  Group::Sektion.seed_once(:name, parent_id: root.id, name: name)
end

Group.rebuild!
