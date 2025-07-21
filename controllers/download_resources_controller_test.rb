# == Schema Information
#
# Table name: download_resources
#
#  id           :integer          not null, primary key
#  app_id       :integer          not null
#  name         :string(255)
#  status       :string(255)      not null
#  user_id      :integer          not null
#  generated_at :datetime
#  from         :datetime
#  to           :datetime
#  url          :text(65535)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
require 'test_helper'

class DownloadResourcesControllerTest < ActionController::TestCase
  setup do
    # FactoryBotを使用してテスト用ユーザーを作成
    @user = FactoryBot.create(:user, :administrator)
    
    # アプリを作成
    @app = FactoryBot.create(:app, :with_manager)
    
    # FactoryBotでダウンロードリソースを作成
    @download_resource = FactoryBot.create(:download_resource, :waiting,
      app: @app,
      user: @user,
      from: 1.week.ago,
      to: Time.current
    )
    
    @generated_resource = FactoryBot.create(:download_resource, :generated,
      app: @app,
      user: @user,
      from: 2.weeks.ago,
      to: 1.week.ago,
      generated_at: 1.day.ago,
      url: 'https://example.com/download.zip'
    )
    
    @failed_resource = FactoryBot.create(:download_resource, :failed,
      app: @app,
      user: @user,
      from: 1.month.ago,
      to: 3.weeks.ago
    )
    
    # ログイン状態にする
    session[:user_id] = @user.id
  end

  test "一覧ページが表示される" do
    get :index
    assert_response :success
    assert_template :index
  end

  test "一覧ページでダウンロードリソースの一覧が表示される" do
    get :index
    assert_response :success
    
    # ダウンロードリソースが表示されることを確認
    assert { assigns(:download_resources).include?(@download_resource) }
    assert { assigns(:download_resources).include?(@generated_resource) }
    assert { assigns(:download_resources).include?(@failed_resource) }
  end

  test "一覧ページでrecentlyスコープが適用される" do
    get :index
    
    # recentlyスコープ（id降順）が適用されることを確認
    download_resources = assigns(:download_resources).to_a
    assert { download_resources.first.id >= download_resources.last.id } if download_resources.count > 1
  end

  test "一覧ページでappとuserの情報が含まれる" do
    get :index
    assert_response :success
    
    # includes(:app, :user)が効いていることを確認
    download_resource_from_assigns = assigns(:download_resources).find { |dr| dr.id == @download_resource.id }
    if download_resource_from_assigns
      assert { download_resource_from_assigns.association(:app).loaded? }
      assert { download_resource_from_assigns.association(:user).loaded? }
    end
  end

  test "一覧ページでページネーションが動作する" do
    get :index, params: { page: 1 }
    assert_response :success
    
    # Kaminariのページネーションが適用されることを確認
    assert { assigns(:download_resources).respond_to?(:current_page) }
    assert { assigns(:download_resources).current_page == 1 }
  end

  test "新しいダウンロードリソースが作成される" do
    assert_difference 'DownloadResource.count', 1 do
      post :create, params: {
        download_resource: {
          app_id: @app.id,
          from: 1.month.ago,
          to: Time.current
        }
      }
    end
    
    assert_redirected_to download_resources_path
    assert { flash[:notice] == 'ファイル作成を受け付けました' }
    
    # 作成されたダウンロードリソースの確認
    created_resource = DownloadResource.last
    assert { created_resource.app == @app }
    assert { created_resource.user == @user }
    assert { created_resource.status.waiting? }
    assert { created_resource.from.present? }
    assert { created_resource.to.present? }
  end

  test "ダウンロードリソース作成時にcurrent_userが設定される" do
    other_user = FactoryBot.create(:user, :administrator)
    
    post :create, params: {
      download_resource: {
        app_id: @app.id,
        user_id: other_user.id, # 別のuser_idを指定してみる
        from: 1.month.ago,
        to: Time.current
      }
    }
    
    # user_idパラメータは無視され、current_userが設定されることを確認
    created_resource = DownloadResource.last
    assert { created_resource.user == @user }
    assert { created_resource.user != other_user }
  end

  test "ダウンロードリソース作成時にDownloadResourceJobがエンキューされる" do
    # Sidekiqジョブの実行をモック
    job_called = false
    job_id = nil
    
    DownloadResourceJob.stub(:perform_async, ->(id) { 
      job_called = true
      job_id = id
    }) do
      post :create, params: {
        download_resource: {
          app_id: @app.id,
          from: 1.month.ago,
          to: Time.current
        }
      }
    end
    
    assert { job_called == true }
    
    created_resource = DownloadResource.last
    assert { job_id == created_resource.id }
  end

  test "無効なダウンロードリソースでエラーメッセージが表示される" do
    # app_idが必須項目
    assert_no_difference 'DownloadResource.count' do
      post :create, params: {
        download_resource: {
          app_id: nil, # 無効な値
          from: 1.month.ago,
          to: Time.current
        }
      }
    end
    
    assert_redirected_to download_resources_path
    assert { flash[:alert].present? }
  end

  test "fromが空の場合にエラーが発生する" do
    assert_no_difference 'DownloadResource.count' do
      post :create, params: {
        download_resource: {
          app_id: @app.id,
          from: nil, # presence: trueで無効
          to: Time.current
        }
      }
    end
    
    assert_redirected_to download_resources_path
    assert { flash[:alert].present? }
  end

  test "toが空の場合にエラーが発生する" do
    assert_no_difference 'DownloadResource.count' do
      post :create, params: {
        download_resource: {
          app_id: @app.id,
          from: 1.month.ago,
          to: nil # presence: trueで無効
        }
      }
    end
    
    assert_redirected_to download_resources_path
    assert { flash[:alert].present? }
  end

  test "download_resource_paramsが正しいパラメータを許可している" do
    params_hash = ActionController::Parameters.new({
      download_resource: {
        app_id: @app.id,
        from: 1.month.ago,
        to: Time.current,
        name: 'should_be_filtered', # 許可されていない
        status: 'should_be_filtered', # 許可されていない
        user_id: 999, # 許可されていない
        url: 'should_be_filtered', # 許可されていない
        generated_at: Time.current # 許可されていない
      }
    })
    
    @controller.params = params_hash
    permitted_params = @controller.send(:download_resource_params)
    
    # 許可されたパラメータのみが含まれることを確認
    assert { permitted_params.has_key?('app_id') }
    assert { permitted_params.has_key?('from') }
    assert { permitted_params.has_key?('to') }
    
    # 許可されていないパラメータが含まれないことを確認
    assert { !permitted_params.has_key?('name') }
    assert { !permitted_params.has_key?('status') }
    assert { !permitted_params.has_key?('user_id') }
    assert { !permitted_params.has_key?('url') }
    assert { !permitted_params.has_key?('generated_at') }
  end

  test "ステータス別のダウンロードリソースが作成される" do
    # waiting状態（デフォルト）
    post :create, params: {
      download_resource: {
        app_id: @app.id,
        from: 1.month.ago,
        to: Time.current
      }
    }
    
    created_resource = DownloadResource.last
    assert { created_resource.status.waiting? }
    assert { created_resource.processing? == true }
    assert { created_resource.processed? == false }
  end

  test "ダウンロードリソースのステータス判定メソッドが正しく動作する" do
    # waiting状態
    assert { @download_resource.processing? == true }
    assert { @download_resource.processed? == false }
    
    # generated状態
    assert { @generated_resource.processing? == false }
    assert { @generated_resource.processed? == true }
    
    # failed状態
    assert { @failed_resource.processing? == false }
    assert { @failed_resource.processed? == true }
  end

  test "ダウンロードリソースのファイル名生成メソッドが正しく動作する" do
    expected_filename = "#{@app.identifier}-#{@download_resource.id}.zip"
    assert { @download_resource.zip_filename == expected_filename }
  end

  test "processing_nameメソッドが正しく動作する" do
    expected_name = "download_resource_#{@download_resource.id}"
    assert { @download_resource.processing_name == expected_name }
  end

  test "delegateメソッドが正しく動作する" do
    # app関連のdelegate
    assert { @download_resource.app_name == @app.name }
    assert { @download_resource.app_identifier == @app.identifier }
    
    # user関連のdelegate
    assert { @download_resource.user_name_or_email == @user.name_or_email }
  end

  test "詳細ページが表示される" do
    # InheritedResourcesにより提供される
    get :show, params: { id: @download_resource.id }
    assert_response :success
    assert_template :show
    assert { assigns(:download_resource) == @download_resource }
  end

  test "存在しないダウンロードリソースの詳細ページで404エラー" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get :show, params: { id: 99999 }
    end
  end

  test "新規作成ページが表示される" do
    # InheritedResourcesにより提供される
    get :new
    assert_response :success
    assert_template :new
    assert { assigns(:download_resource).is_a?(DownloadResource) }
  end

  test "編集ページが表示される" do
    # InheritedResourcesにより提供される
    get :edit, params: { id: @download_resource.id }
    assert_response :success
    assert_template :edit
    assert { assigns(:download_resource) == @download_resource }
  end

  test "ダウンロードリソースの更新が動作する" do
    # InheritedResourcesにより提供される
    new_from = 2.months.ago
    
    patch :update, params: {
      id: @download_resource.id,
      download_resource: {
        app_id: @app.id,
        from: new_from,
        to: @download_resource.to
      }
    }
    
    assert_redirected_to download_resource_path(@download_resource)
    
    @download_resource.reload
    assert { @download_resource.from.to_date == new_from.to_date }
  end

  test "ダウンロードリソースの削除が動作する" do
    # InheritedResourcesにより提供される
    assert_difference 'DownloadResource.count', -1 do
      delete :destroy, params: { id: @download_resource.id }
    end
    
    assert_redirected_to download_resources_path
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

  test "watcherユーザーもアクセスでる" do
    watcher_user = FactoryBot.create(:user, :watcher)
    session[:user_id] = watcher_user.id
    
    get :index
    assert_response :success
  end

  test "国際化メッセージが正しく表示される" do
    post :create, params: {
      download_resource: {
        app_id: @app.id,
        from: 1.month.ago,
        to: Time.current
      }
    }
    
    assert_redirected_to download_resources_path
    
    # ja.ymlで定義されたメッセージが使用される
    assert { flash[:notice] == 'ファイル作成を受け付けました' }
  end

  test "異なるアプリでのダウンロードリソース作成" do
    other_app = FactoryBot.create(:app, :with_manager)
    
    assert_difference 'DownloadResource.count', 1 do
      post :create, params: {
        download_resource: {
          app_id: other_app.id,
          from: 1.month.ago,
          to: Time.current
        }
      }
    end
    
    created_resource = DownloadResource.last
    assert { created_resource.app == other_app }
  end

  test "日付パラメータが正しく処理される" do
    from_date = Date.new(2025, 1, 1)
    to_date = Date.new(2025, 1, 31)
    
    post :create, params: {
      download_resource: {
        app_id: @app.id,
        from: from_date,
        to: to_date
      }
    }
    
    created_resource = DownloadResource.last
    assert { created_resource.from.to_date == from_date }
    assert { created_resource.to.to_date == to_date }
  end

  test "InheritedResourcesViewsのメソッドが利用可能" do
    get :index
    
    # InheritedResourcesViewsのメソッドがヘルパーメソッドとして利用可能
    assert { @controller.respond_to?(:index_attributes, true) }
    assert { @controller.respond_to?(:show_attributes, true) }
    assert { @controller.respond_to?(:edit_attributes, true) }
    assert { @controller.respond_to?(:enable_actions, true) }
  end

  test "indexアクションでindex!が呼ばれる" do
    # index!はInheritedResourcesのメソッド
    # カタムロジック実行後にindex!が呼ばれることを確認
    
    get :index
    assert_response :success
    
    # @download_resourcesが設定されていることを確認
    assert { assigns(:download_resources).present? }
  end

  test "エラーハンドリングでfull_messagesが正しく表示される" do
    # バリデーションエラーのモック
    DownloadResource.any_instance.stub(:save, false) do
      # エラーメッセージをモック
      errors_double = double('Errors')
      allow(errors_double).to receive(:full_messages).and_return(['App必須です', 'From必須です'])
      
      DownloadResource.any_instance.stub(:errors, errors_double) do
        post :create, params: {
          download_resource: {
            app_id: @app.id,
            from: 1.month.ago,
            to: Time.current
          }
        }
      end
    end
    
    assert_redirected_to download_resources_path
    assert { flash[:alert] == 'App必須です From必須です' }
  end

  test "DownloadResourceJobが例外を発生させてもコントローラーは正常動作する" do
    # ジョブが例外を発生させる場合のテスト
    DownloadResourceJob.stub(:perform_async, -> (*args) { raise StandardError.new('Job failed') }) do
      # 例外が発生してもリクエストは成功する（非同期処理のため）
      assert_difference 'DownloadResource.count', 1 do
        post :create, params: {
          download_resource: {
            app_id: @app.id,
            from: 1.month.ago,
            to: Time.current
          }
        }
      end
    end
    
    assert_redirected_to download_resources_path
    assert { flash[:notice] == 'ファイル作成を受け付けました' }
  end

  test "複数ページにわたるダウンロードリソースのページネーション" do
    # 追加のダウンロードリソースを作成
    10.times do |i|
      FactoryBot.create(:download_resource, :waiting,
        app: @app,
        user: @user,
        from: (i + 1).days.ago,
        to: Time.current
      )
    end
    
    get :index, params: { page: 2 }
    assert_response :success
    
    # 2ページ目のデータが取得されることを確認
    assert { assigns(:download_resources).current_page == 2 }
  end

  test "様々なステータスのダウンロードリソースが一覧に表示される" do
    # 各ステータスのリソースを作成
    generating_resource = FactoryBot.create(:download_resource, :generating, app: @app, user: @user)
    
    get :index
    
    download_resources = assigns(:download_resources)
    statuses = download_resources.map(&:status)
    
    # 様々なステータスが含まれることを確認
    assert { statuses.any? { |s| s.waiting? } }
    assert { statuses.any? { |s| s.generating? } }
    assert { statuses.any? { |s| s.generated? } }
    assert { statuses.any? { |s| s.failed? } }
  end

  test "DownloadResourceモデルのuploadメソッドが定義されている" do
    # uploadメソッド存在することを確認
    assert { @download_resource.respond_to?(:upload) }
  end
end
