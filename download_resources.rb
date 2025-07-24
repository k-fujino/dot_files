# test/factories/download_resources.rb
FactoryBot.define do
  factory :download_resource do
    association :app
    from { 1.month.ago }
    to { Date.current }
    # 他の必要な属性があれば追加
    
    trait :with_long_range do
      from { 6.months.ago }
      to { Date.current }
    end
    
    trait :recent do
      from { 1.week.ago }
      to { Date.current }
    end
  end
end
