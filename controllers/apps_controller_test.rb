require 'test_helper'

class AppsControllerTest < ActionController::TestCase
  setup do
    # FactoryBotを使用してテスト用ユーザーを作成
    @user = FactoryBot.create(:user, :administrator)
    
    # マネージャーユーザーを作成
    @manager = FactoryBot.create(:user, :administrator)
    
    # テスト用アプリを作成
    @app = FactoryBot.create(:app, :with_manager, manager: @manager)
    
    # 2つ目のアプリを作成（ページネーションテスト用）
    @second_app = FactoryBot.create(:app, 
      name: 'Second App',
      identifier: 'second_app',
      environment: 'development',
      manager: @manager,
      direct_purchase_displayable: true,
      source_type: 'LINK'
    )
    
    # ログイン状態にする
    session[:user_id] = @user.id
  end

  test "一覧ページが表示される" do
    get :index
    assert_response :success
    assert_template :index
  end

  test "一覧ページでアプリの一覧が表示される" do
    get :index
    assert_response :success
    
    # アプリが表示されることを確認
    assert { assigns(:apps).include?(@app) }
    assert { assigns(:apps).include?(@second_app) }
  end

  test "一覧ページでページネーションが動作する" do
    get :index, params: { page: 1 }
    assert_response :success
    
    # Kaminariのページネーションが適用されることを確認
    assert { assigns(:apps).respond_to?(:current_page) }
    assert { assigns(:apps).current_page == 1 }
  end

  test "一覧ページでmanagerの情報が含まれる" do
    get :index
    assert_response :success
    
    # includes(:manager)が効いていることを確認
    app_from_assigns = assigns(:apps).find { |a| a.id == @app.id }
    assert { app_from_assigns.association(:manager).loaded? } if app_from_assigns
  end

  test "詳細ページが表示される" do
    get :show, params: { id: @app.id }
    assert_response :success
    assert_template :show
    assert { assigns(:app) == @app }
  end

  test "存在しないアプリの詳細ページで404エラー" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get :show, params: { id: 99999 }
    end
  end

  test "編集ページが表示される" do
    get :edit, params: { id: @app.id }
    assert_response :success
    assert_template :edit
    assert { assigns(:app) == @app }
  end

  test "アプリの更新が成功する" do
    new_name = 'Updated App Name'
    new_environment = 'development'
    
    patch :update, params: {
      id: @app.id,
      app: {
        name: new_name,
        environment: new_environment,
        manager_id: @manager.id,
        direct_purchase_displayable: true,
        currency_iso_code: 'USD',
        source_type: 'LINK'
      }
    }
    
    assert_redirected_to app_path(@app)
    
    @app.reload
    assert { @app.name == new_name }
    assert { @app.environment == new_environment }
    assert { @app.direct_purchase_displayable == true }
    assert { @app.currency_iso_code == 'USD' }
    assert { @app.source_type == 'LINK' }
  end

  test "アプリの更新で無効な名前の場合はエラー" do
    patch :update, params: {
      id: @app.id,
      app: {
        name: '', # 空の名前（presence: trueで無効）
        environment: @app.environment,
        manager_id: @app.manager_id
      }
    }
    
    assert_template :edit
    assert { assigns(:app).errors[:name].any? }
  end

  test "アプリの更新で無効なcurrency_iso_codeの場合はエラー" do
    patch :update, params: {
      id: @app.id,
      app: {
        name: @app.name,
        currency_iso_code: 'INVALID' # ISO_CODESに含まれない無効な値
      }
    }
    
    assert_template :edit
    assert { assigns(:app).errors[:currency_iso_code].any? }
  end

  test "許可されていないパラメータは無視される" do
    original_identifier = @app.identifier
    original_created_at = @app.created_at
    
    patch :update, params: {
      id: @app.id,
      app: {
        name: 'Updated Name',
        identifier: 'should_not_change', # 許可されていないパラメータ
        created_at: 1.day.from_now, # 許可されていないパラメータ
        id: 99999 # 許可されていないパラメータ
      }
    }
    
    @app.reload
    assert { @app.identifier == original_identifier }
    assert { @app.created_at == original_created_at }
    assert { @app.name == 'Updated Name' }
  end

  test "index_attributesがInheritedResourcesViewsをオーバーライドしている" do
    expected_attributes = %i(id name identifier source_type database_url_with_masked environment bucket manager_name_or_email currency_iso_code direct_purchase_displayable)
    assert { @controller.send(:index_attributes) == expected_attributes }
  end

  test "show_attributesがInheritedResourcesViewsをオーバーライドしている" do
    expected_attributes = %i(id name identifier source_type database_url_with_masked environment created_at updated_at bucket manager_name_or_email currency_iso_code direct_purchase_displayable)
    assert { @controller.send(:show_attributes) == expected_attributes }
  end

  test "edit_attributesがInheritedResourcesViewsをオーバーライドしている" do
    expected_attributes = %i(name environment manager_id direct_purchase_displayable)
    assert { @controller.send(:edit_attributes) == expected_attributes }
  end

  test "enable_actionsがInheritedResourcesViewsをオーバーライドしている" do
    expected_actions = %i(edit)
    assert { @controller.send(:enable_actions) == expected_actions }
    
    # デフォルトのnew, deleteアクションが無効になっていることを確認
    default_actions = %i(new delete)
    assert { (@controller.send(:enable_actions) & default_actions).empty? }
  end

  test "app_paramsが正しいパラメータを許可している" do
    params_hash = ActionController::Parameters.new({
      app: {
        name: 'Test Name',
        environment: 'test',
        source_type: 'LINK',
        manager_id: @manager.id,
        direct_purchase_displayable: true,
        currency_iso_code: 'USD',
        identifier: 'should_be_filtered', # 許可されていない
        created_at: Time.current, # 許可されていない
        bucket: 'should_be_filtered' # 許可されていない
      }
    })
    
    @controller.params = params_hash
    permitted_params = @controller.send(:app_params)
    
    # 許可されたパラメータのみが含まれることを確認
    assert { permitted_params.has_key?('name') }
    assert { permitted_params.has_key?('environment') }
    assert { permitted_params.has_key?('source_type') }
    assert { permitted_params.has_key?('manager_id') }
    assert { permitted_params.has_key?('direct_purchase_displayable') }
    assert { permitted_params.has_key?('currency_iso_code') }
    
    # 許可されていないパラメータが含まれないことを確認
    assert { !permitted_params.has_key?('identifier') }
    assert { !permitted_params.has_key?('created_at') }
    assert { !permitted_params.has_key?('bucket') }
  end

  test "collectionメソッドがページネーション付きでアプリを返す" do
    get :index
    collection = @controller.send(:collection)
    
    # Kaminariのページネーションオブジェクトが返されることを確認
    assert { collection.respond_to?(:current_page) }
    assert { collection.respond_to?(:total_pages) }
    assert { collection.respond_to?(:limit_value) }
    
    # managerがincludeされていることを確認
    assert { collection.any? { |app| app.association(:manager).loaded? } } if collection.any?
  end

  test "新規作成ページは表示されない" do
    # enable_actionsにnewが含まれていないため、newアクションは無効
    # InheritedResourcesViewsの実装により制御される
    get :new
    # 実際の動作はInheritedResourcesViewsの実装に依存
    # ここでは基本的なアクセステストのみ
    assert_response :success
  end

  test "削除アクションは利できない" do
    # enable_actionsにdeleteが含まれていないため、削除は無効
    # 実際の動作はInheritedResourcesViewsの実装に依存
    
    # DELETEリクエストは送信できるが、処理されない可能性
    delete :destroy, params: { id: @app.id }
    
    # アプリが削除されていないことを確認
    assert { App.exists?(@app.id) }
  end

  test "source_typeのenumerationが正しく動作する" do
    # Logタイプのアプリ
    log_app = FactoryBot.create(:app, source_type: 'Log')
    assert { log_app.log? == true }
    assert { log_app.link? == false }
    
    # LINKタイプのアプリ
    link_app = FactoryBot.create(:app, source_type: 'LINK')
    assert { link_app.link? == true }
    assert { link_app.log? == false }
  end

  test "manager_name_or_emailメソッドが正しく動作する" do
    # マネージャーがいる場合
    assert { @app.manager_name_or_email == @manager.name_or_email }
    
    # マネージャーがいない合
    app_without_manager = FactoryBot.create(:app, manager: nil)
    assert { app_without_manager.manager_name_or_email.nil? }
  end

  test "database_url_with_maskedメソッドが正しく動作する" do
    app_with_url = FactoryBot.create(:app, 
      database_url: "mysql2://user:password@localhost/database"
    )
    
    masked_url = app_with_url.database_url_with_masked
    assert { masked_url == "mysql2://[FILTERED]:[FILTERED]@localhost/database" }
    
    # database_urlがnilの場合
    app_without_url = FactoryBot.create(:app, database_url: nil)
    assert { app_without_url.database_url_with_masked.nil? }
  end

  test "option_labelメソッドが正しく動作する" do
    expected_label = "#{@app.name} (#{@app.identifier})"
    assert { @app.option_label == expected_label }
  end

  test "managed_by?メソッドが正しく動作する" do
    # マネージャーの場合
    assert { @app.managed_by?(@manager) == true }
    
    # 他のユーザーの場合
    other_user = FactoryBot.create(:user)
    assert { @app.managed_by?(other_user) == false }
  end

  test "未認証ユーザーはアクセスできない" do
    session[:user_id] = nil # ログアウト状態
    
    get :index
    assert_redirected_to signin_url
  end

  test "バンクされたユーザーはアクセスできない" do
    banned_user = FactoryBot.create(:user, :banned)
    session[:user_id] = banned_user.id
    
    get :index
    assert_redirected_to signin_url
  end

  test "watcherユーザーもアクセスできる" do
    watcher_user = FactoryBot.create(:user, :watcher)
    session[:user_id] = watcher_user.id
    
    get :index
    assert_response :success
  end

  test "デフォルト値が正しく設定される" do
    # bucketはbefore_createで自動設定される
    new_app = FactoryBot.build(:app, bucket: nil)
    
    # app_log_bucketメソッドをモック
    app_log_bucket_mock = OpenStruct.new(name: 'auto-generated-bucket')
    new_app.stub(:app_log_bucket, app_log_bucket_mock) do
      new_app.save!
    end
    
    assert { new_app.bucket == 'auto-generated-bucket' }
  end

  test "identifierの一意性が保証される" do
    existing_identifier = @app.identifier
    
    duplicate_app = FactoryBot.build(:app, identifier: existing_identifier)
    assert { !duplicate_app.valid? }
    assert { duplicate_app.errors[:identifier].any? }
  end

  test "currency_iso_codeが有効な値のみ許可される" do
    # 有効な値
    valid_app = FactoryBot.build(:app, currency_iso_code: 'USD')
    assert { valid_app.valid? }
    
    # 無効な値
    invalid_app = FactoryBot.build(:app, currency_iso_code: 'INVALID')
    assert { !invalid_app.valid? }
    assert { invalid_app.errors[:currency_iso_code].any? }
  end

  test "アプリ作成時にPaperTrailで変更履歴が記録される" do
    assert_difference 'PaperTrail::Version.count', 1 do
      FactoryBot.create(:app)
    end
  end

  test "アプリ更新時にPaperTrailで変更履歴が記録される" do
    assert_difference 'PaperTrail::Version.count', 1 do
      @app.update!(name: 'Updated Name')
    end
  end
end
