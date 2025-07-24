# test/factories/versions.rb
FactoryBot.define do
  factory :version do
    item_type { "User" }
    sequence(:item_id) { |n| n }
    event { "create" }
    whodunnit { "1" }
    object { nil }
    object_changes { nil }
    created_at { Time.current }
  end
end
