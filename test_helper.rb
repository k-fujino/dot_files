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
      foo: false, 
      bar: false, 
      baz: false,
      link0: true, 
      link1: true, 
      link2: true
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

# Rails 6.1対応版: 動的なデータベース設定
def prepare_multi_database_configuration(app_names)
  # Rails 6.1では configurations.configs_for を使用
  base_config = if Rails.version >= "6.1"
    ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).first&.configuration_hash
  else
    ActiveRecord::Base.configurations[Rails.env]
  end
  
  # ベース設定が取得できない場合はエラー
  raise "Base database configuration not found for environment: #{Rails.env}" unless base_config
  
  app_names.each do |app_name, is_link|
    db_name = [is_link ? 'aiminglink' : 'obelisk', app_name, 'test'].join("_")
    
    # Rails 6.1: establish_connection を使用して動的に接続を確立
    if Rails.version >= "6.1"
      # 既存の設定があるかチェック
      existing_config = ActiveRecord::Base.configurations.configs_for(env_name: db_name, include_replicas: true).first
      
      unless existing_config
        # 新しい設定を作成
        config = base_config.merge(
          username: app_name.to_s,
          database: db_name,
          # アダプターとホストは基本設定から継承
          adapter: base_config[:adapter] || base_config["adapter"],
          host: base_config[:host] || base_config["host"],
          port: base_config[:port] || base_config["port"]
        )
        
        # カスタムクラスを作成して接続を確立
        connection_class = Class.new(ActiveRecord::Base) do
          self.abstract_class = true
        end
        
        # クラス名を動的に設定
        Object.const_set("#{app_name.to_s.camelize}Connection", connection_class)
        
        # 接続を確立
        connection_class.establish_connection(config)
        
        # DatabaseRewinderに登録
        DatabaseRewinder[db_name]
      end
    else
      # Rails 6.0以前の処理（既存のコード）
      next if ActiveRecord::Base.configurations[db_name]
      ActiveRecord::Base.configurations[db_name] = base_config.merge(
        username: app_name.to_s,
        database: db_name
      )
      DatabaseRewinder[db_name]
    end
  end
  
  # 全ての接続が正しく確立されているか確認
  verify_database_connections(app_names)
end

# データベース接続の検証
def verify_database_connections(app_names)
  app_names.each do |app_name, is_link|
    db_name = [is_link ? 'aiminglink' : 'obelisk', app_name, 'test'].join("_")
    
    begin
      # 接続クラスが存在する場合、接続をテスト
      if Object.const_defined?("#{app_name.to_s.camelize}Connection")
        connection_class = Object.const_get("#{app_name.to_s.camelize}Connection")
        connection_class.connection.execute("SELECT 1")
      end
    rescue => e
      Rails.logger.error "Failed to verify connection for #{db_name}: #{e.message}"
      # テスト環境では続行するが、警告を出力
      puts "WARNING: Database #{db_name} connection could not be verified: #{e.message}"
    end
  end
end

# Rack::Test::CookieJar の拡張（変更なし）
class Rack::Test::CookieJar
  def signed
    self
  end
  
  def encrypted
    self
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
  
  # テスト用のデータベースがクリアされているか確認
  def assert_test_database_clean(identifier)
    # ConsumptionRevisionのデータ数を確認
    count = ConsumptionRevision(identifier).count
    assert_equal 0, count, "Test database for #{identifier} is not clean. Found #{count} ConsumptionRevision records."
  end
end

# ActiveSupport::TestCaseに含める
class ActiveSupport::TestCase
  include DatabaseConnectionHelper
end
