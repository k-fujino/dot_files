# == Schema Information
#
# Table name: processing_results
#
#  id             :integer          not null, primary key
#  app_id         :integer
#  name           :string(255)      not null
#  status         :string(255)      not null
#  started_at     :datetime         not null
#  finished_at    :datetime
#  detail         :text(65535)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  app_identifier :string(255)
#

#FactoryBot.define do
#  factory :processing_result do
#    association :app, factory: :app
#
#    name        { 'name'       }
#    status      { :success     }
#    started_at  { Time.current }
#    finished_at { Time.current }
#
#    trait :success do
#      status { :success }
#    end
#
#    trait :error do
#      status { :error }
#    end
#
#    trait :ignore do
#      status { :ignore }
#    end
#  end
#end

# test/factories/processing_results.rb
FactoryBot.define do
  factory :processing_result do
    association :app, factory: :app
    sequence(:name) { |n| "処理結果#{n}" }
    status { :success } # enumerizeの値: running, success, error, ignored, ignore
    started_at { 2.hours.ago }
    finished_at { 1.hour.ago }
    detail { "処理結果の詳細情報" }
    app_identifier { nil } # appが存在する場合は通常nil
    
    # appなしのprocessing_result用trait
    trait :without_app do
      app { nil }
      app_identifier { "standalone_identifier" }
    end
    
    # 実行中のprocessing_result用trait
    trait :running do
      status { :running }
      finished_at { nil }
    end
    
    # エラーのprocessing_result用trait  
    trait :with_error do
      status { :error }
      detail { "エラーが発生しました\nスタックトレース情報" }
    end
  end
end
