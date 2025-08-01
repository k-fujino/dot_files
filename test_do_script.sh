#!/bin/bash
# テスト実行スクリプト - データベース接続問題の解決版

set -e

echo "=== obelisk テスト実行スクリプト ==="

# Step 1: 環境の確認
echo "Step 1: 現在の環境確認"
echo "----------------------------------------"

# コンテナの状態確認
echo "コンテナの状態:"
docker-compose ps

# データベースの接続確認
echo ""
echo "データベース接続テスト:"
if docker-compose exec db mysql -u root -e "SELECT 1;" > /dev/null 2>&1; then
    echo "✅ データベース接続: 成功"
else
    echo "❌ データベース接続: 失敗"
    echo "データベースを再起動します..."
    docker-compose restart db
    sleep 10
fi

# Step 2: 環境変数の確認
echo ""
echo "Step 2: 環境変数の確認"
echo "----------------------------------------"

echo "Rails環境で使用される環境変数:"
docker-compose exec obelisk env | grep -E "(DATABASE|RAILS_ENV|MYSQL)" || echo "関連する環境変数が見つかりませんした"

# Step 3: データベースの準備
echo ""
echo "Step 3: テストデータベースの準備"
echo "----------------------------------------"

# テストデータベースが存在するか確認
echo "テストデータベースの存在確認:"
if docker-compose exec db mysql -u root -e "USE obeliskapp_test; SELECT 1;" > /dev/null 2>&1; then
    echo "✅ テストデータベースが存在します"
else
    echo "⚠️  テストデータベースが存在しません。作成します..."
    docker-compose exec obelisk bash -c "RAILS_ENV=test bin/rails db:create"
fi

# マイグレーションの実行
echo "テストデータベースのマイグレーション:"
docker-compose exec obelisk bash -c "RAILS_ENV=test bin/rails db:migrate"

# Step 4: Rails設定の確認
echo ""
echo "Step 4: Rails設定の確認"
echo "----------------------------------------"

echo "データベース設定の確認:"
docker-compose exec obelisk bash -c "RAILS_ENV=test bin/rails runner '
puts \"Rails environment: #{Rails.env}\"
puts \"Database config:\"
config = Rails.application.config.database_configuration[Rails.env]
puts \"  adapter: #{config[\"adapter\"]}\"
puts \"  database: #{config[\"database\"]}\"
puts \"  username: #{config[\"username\"]}\"
puts \"  password: #{config[\"password\"].present? ? \"[SET]\" : \"[EMPTY]\"}\"
puts \"  url: #{config[\"url\"]}\"
'"

# Step 5: データベース接続テスト
echo ""
echo "Step 5: Rails経由でのデータベース接続テスト"
echo "----------------------------------------"

echo "ActiveRecord経由でのデータベース接続テスト:"
if docker-compose exec obelisk bash -c "RAILS_ENV=test bin/rails runner 'ActiveRecord::Base.connection.execute(\"SELECT 1\"); puts \"✅ ActiveRecord connection successful\"'"; then
    echo "データベース接続は正常です"
else
    echo "❌ ActiveRecord接続でエラーが発生しました"
    
    # デバッグ情報の収集
    echo ""
    echo "デバッグ情報:"
    echo "コンテナのネットワーク情報:"
    docker-compose exec obelisk cat /etc/hosts
    
    echo ""
    echo "データベースサーバーへの接続テスト:"
    docker-compose exec obelisk mysql -h db -u root -e "SELECT 1;" || echo "直接接続に失敗"
    
    exit 1
fi

# Step 6: テスト実行
echo ""
echo "Step 6: テスト実行"
echo "----------------------------------------"

echo "Railsテストを実行します..."

# 環境変数を明示的に設定してテスト実行
docker-compose exec -e RAILS_ENV=test -e DATABASE_URL="mysql2://root@db:3306/obeliskapp_test" obelisk bin/rails test

echo ""
echo "✅ テスト実行完了"

# 使用方法の説明
cat << 'EOF'

=== 使用方法 ===

このスクリプト実行後、個別にテストを実行する場合:

1. 全テスト実行:
   docker-compose exec -e RAILS_ENV=test obelisk bin/rails test

2. 特定のテストファイル実行:
   docker-compose exec -e RAILS_ENV=test obelisk bin/rails test test/models/user_test.rb

3. デバッグモーでコンソール起動:
   docker-compose exec -e RAILS_ENV=test obelisk bin/rails console

4. データベースの状態確認:
   docker-compose exec obelisk bash -c "RAILS_ENV=test bin/rails db:version"

=== トラブルシューティング ===

もしまだ接続エラーが発生する場合:

1. 完全なクリーンアップ:
   docker-compose down --volumes
   docker-compose up -d

2. データベースの初期化:
   docker-compose exec obelisk bash -c "RAILS_ENV=test bin/rails db:drop db:create db:migrate"

3. 環境変数の確認:
   docker-compose exec obelisk env | grep DATABASE

EOF
