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
  # Rails 6.1以降の非推奨警告を一時的に抑制
  original_deprecation = ActiveSupport::Deprecation.silenced
  ActiveSupport::Deprecation.silenced = true
  
  begin
    base = ActiveRecord::Base.configurations[Rails.env]
    app_names.each do |app_name, is_link|
      db = [is_link ? 'aiminglink' : 'obelisk', app_name, 'test'].join("_")
      next if ActiveRecord::Base.configurations[db]
      
      # Rails 6.1以降でも動作する方法で設定を追加
      if Rails.version >= '6.1'
        # 新しい方法：configurationsを直接操作せずに内部的に追加
        config_hash = base.merge(
          'username' => app_name.to_s,
          'database' => db,
        )
        
        # 現在の設定に追加
        current_configs = Rails.application.config.database_configuration
        current_configs[db] = config_hash
        
        # DatabaseConfigurationsオブジェクトを再作成
        new_configurations = ActiveRecord::DatabaseConfigurations.new(current_configs)
        ActiveRecord::Base.configurations = new_configurations
      else
        # Rails 6.0以前の方法
        ActiveRecord::Base.configurations[db] = base.merge(
          username: app_name,
          database: db,
        )
      end
      
      DatabaseRewinder[db]
    end
  ensure
    # 非推奨警告の設定を元に戻す
    ActiveSupport::Deprecation.silenced = original_deprecation
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
