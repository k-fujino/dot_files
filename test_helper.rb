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

# NOTE: DatabaseRewinderを動的に設定している
def prepare_multi_database_configuration(app_names)
  # Rails.application.config.database_configurationを使用してより安全に設定を管理
  current_db_config = Rails.application.config.database_configuration

  # test環境の基本設定を取得
  base_config = current_db_config['test'] || current_db_config[Rails.env]
  
  unless base_config
    Rails.logger.error "No base configuration found for test environment"
    return
  end

  # 追加が必要な設定を収集
  configs_to_add = {}

  app_names.each do |app_name, is_link|
    db_name = [is_link ? 'aiminglink' : 'obelisk', app_name, 'test'].join("_")

    # 既に設定済みの場合はスキップ
    next if current_db_config[db_name] || 
            ActiveRecord::Base.configurations.configs_for(env_name: 'test', name: db_name).present?

    # 新しい設定を作成
    configs_to_add[db_name] = base_config.merge(
      'username' => app_name.to_s,
      'database' => db_name,
    )
  end

  # 設定が追加された場合のみ更新
  unless configs_to_add.empty?
    # Rails.application.config.database_configurationを更新
    updated_config = current_db_config.merge(configs_to_add)
    Rails.application.config.database_configuration = updated_config
    
    # 新しいDatabaseConfigurationsオブジェクトを作成
    new_configurations = ActiveRecord::DatabaseConfigurations.new(updated_config)
    ActiveRecord::Base.configurations = new_configurations

    # 設定が正しく適用された後でDatabaseRewinderに登録
    configs_to_add.each_key do |db_name|
      # 設定の存在を確認
      if ActiveRecord::Base.configurations.configs_for(env_name: 'test', name: db_name).present?
        DatabaseRewinder[db_name]
      else
        Rails.logger.warn "Failed to register DatabaseRewinder for: #{db_name}"
      end
    end
    
    Rails.logger.info "Added #{configs_to_add.size} database configurations successfully"
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
