ENV["RAILS_ENV"] = "test"
require File.expand_path('../config/environment', __dir__)

require "rails/test_help"
require "active_support/testing/metadata"
require "minitest/power_assert"

require "rr"
require "sidekiq/testing"
require "fakefs/safe"

Dir.glob(Rails.root + "test/support/**/*.rb").each { |file| require file }

# https://github.com/thoughtbot/factory_bot/commit/d0208eda9c65cbc476a02d2f7503234195610005
FactoryBot.use_parent_strategy = false

class ActiveSupport::TestCase
  self.use_transactional_tests = false
  include FactoryBot::Syntax::Methods

  fixtures :all

  setup do
    prepare_multi_database_configuration(
      foo: false, bar: false, baz: false,
      link0: true, link1: true, link2: true,
    )

    if metadata[:js] == true
      DatabaseRewinder.strategy = :truncation
    else
      DatabaseRewinder.strategy = :transaction
    end

    DatabaseRewinder.clean_all
    AppLogDatabase.ensure_apps

    Bullet.start_request
  end

  teardown do
    Bullet.perform_out_of_channel_notifications if Bullet.notification?
    Bullet.end_request
    DatabaseRewinder.clean
    AppLogDatabase.ensure_apps
    Sidekiq::Worker.clear_all
    travel_back
  end
end

# Rails 6.1以降対応：DatabaseConfigurationsを直接操作する方法
def prepare_multi_database_configuration(app_names)
  # Rails 6.1以降での新しい方法
  if Rails.version >= '6.1'
    prepare_multi_database_configuration_rails61(app_names)
  else
    prepare_multi_database_configuration_legacy(app_names)
  end
end

# Rails 6.1以降用の設定メソッド
def prepare_multi_database_configuration_rails61(app_names)
  # 現在の設定を取得
  current_configs = Rails.application.config.database_configuration
  base_config = current_configs[Rails.env]
  
  # 追加するデータベース設定を構築
  additional_configs = {}
  
  app_names.each do |app_name, is_link|
    db = [is_link ? 'aiminglink' : 'obelisk', app_name, 'test'].join("_")
    
    # 既に設定済みの場合はスキップ
    existing_config = ActiveRecord::Base.configurations.configs_for(env_name: 'test', name: db)
    next if existing_config
    
    # 新しい設定を追加
    additional_configs[db] = base_config.merge(
      'username' => app_name.to_s,
      'database' => db,
    )
    
    # DatabaseRewinderに登録
    DatabaseRewinder[db]
  end
  
  # 設定が追加された場合のみ、新しいDatabaseConfigurationsオブジェクトを作成
  unless additional_configs.empty?
    merged_configs = current_configs.merge(additional_configs)
    new_configurations = ActiveRecord::DatabaseConfigurations.new(merged_configs)
    
    # アプリケーションに新しい設定を適用
    Rails.application.config.database_configuration = merged_configs
    ActiveRecord::Base.configurations = new_configurations
  end
end

# Rails 6.0以前用の設定メソッド（互換性のため）
def prepare_multi_database_configuration_legacy(app_names)
  base = ActiveRecord::Base.configurations[Rails.env]
  app_names.each do |app_name, is_link|
    db = [is_link ? 'aiminglink' : 'obelisk', app_name, 'test'].join("_")
    next if ActiveRecord::Base.configurations[db]
    ActiveRecord::Base.configurations[db] = base.merge(
      username: app_name,
      database: db,
    )
    DatabaseRewinder[db]
  end
end

# データベース接続エラーを共通的に処理するヘルパー
module DatabaseConnectionHelper
  def skip_if_database_error
    yield
  rescue Mysql2::Error::ConnectionError => e
    skip "MySQL connection error: #{e.message}"
  rescue ActionView::Template::Error => e
    if e.message.include?("Access denied")
      skip "Database access denied: #{e.message}"
    else
      raise
    end
  end
end
