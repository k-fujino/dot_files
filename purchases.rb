# test/factories/purchases.rb
FactoryBot.define do
  factory :purchase do
    association :app
    sequence(:identifier) { |n| "purchase_#{n}" }
    sequence(:player_identifier) { |n| "player_#{n}" }
    store_type { "app_store" }
    points { 1000 }
    price { 120 }
    purchased_at { Time.current }
    purchased_on { Date.current }
  end
end
