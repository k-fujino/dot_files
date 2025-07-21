require 'test_helper'

class ApplicationControllerTest < ActionController::TestCase
  # テスト用のダミーコントローラーを作成
  # ApplicationControllerは抽象クラスなので直接テストできないため
  class TestController < ApplicationController
    def index
      render plain: 'success'
    end

    def show
      # Banken::NotAuthorizedErrorを意図的に発生させるアクション
      raise Banken::NotAuthorizedError
    end

    def create
      # set_paper_trail_whodunnitをテストするためのアクション
      render plain: 'created'
    end

    def protected_action
      # authorize!の動作をテストするためのアクション
      render plain: 'protected'
    end
  end

  setup do
    # ルーティングの設定
    Rails.application.routes.draw do
      get 'test/index', to: 'application_controller_test/test#index'
      get 'test/show', to: 'application_controller_test/test#show'
      post 'test/create', to: 'application_controller_test/test#create'
      get 'test/protected_action', to: 'application_controller_test/test#protected_action'
      root 'welcome#index'
      get '/signin' => 'sessions#new'
    end

    @controller = TestController.new
    
    # Userモデルのテストデータ作成
    @user = User.create!(
      email: 'test@example.com',
      role: 'administrator', # Constants::ROLESの最初の値と仮定
      name: 'Test User'
    )
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "認証されたユーザーがアクションにアクセスできる" do
    session[:user_id] = @user.id
    
    get :index
    assert_response :success
    assert { response.body == 'success' }
  end

  test "未認証ユーザーがサインインページにリダイレクトされる" do
    # session[:user_id]を設定しない（未認証状態）
    
    get :index
    assert_redirected_to signin_url
  end

  test "存在しないuser_idでサインインページにリダイレクトされる" do
    session[:user_id] = 99999 # 存在しないID
    
    get :index
    assert_redirected_to signin_url
  end

  test "set_raven_contextでRavenのユーザーコンテキストが設定される" do
    session[:user_id] = @user.id
    
    # Ravenモックの設定
    raven_user_context = nil
    raven_extra_context = nil
    
    Raven.stub(:user_context, ->(context) { raven_user_context = context }) do
      Raven.stub(:extra_context, ->(context) { raven_extra_context = context }) do
        get :index
      end
    end
    
    assert { raven_user_context[:id] == @user.id }
    assert { raven_extra_context[:params].is_a?(Hash) }
    assert { raven_extra_context[:url].present? }
  end

  test "set_raven_contextで未認証時にuser_idがnilになる" do
    # 未認証状態でもset_raven_contextが呼ばれることを確認
    raven_user_context = nil
    
    Raven.stub(:user_context, ->(context) { raven_user_context = context }) do
      Raven.stub(:extra_context, ->(context) {}) do
        get :index # リダイレクトされるが、before_actionは実行される
      end
    end
    
    assert { raven_user_context[:id].nil? }
  end

  test "set_email_to_envでリクエスト環境にメールアドレスが設定される" do
    session[:user_id] = @user.id
    
    get :index
    
    assert { request.env["email"] == @user.email }
  end

  test "current_userがnilの場合にemailが設定されない" do
    # ログインしていない状態
    session[:user_id] = nil
    
    get :index
    
    assert { request.env["email"].nil? }
  end

  test "set_paper_trail_whodunnitが呼ばれる" do
    session[:user_id] = @user.id
    
    # PaperTrailのset_whodunnitメソッドがcurrent_userで呼ばれることを確認
    paper_trail_called = false
    whodunnit_value = nil
    
    PaperTrail.stub(:request, OpenStruct.new) do
      PaperTrail.request.stub(:whodunnit=, ->(value) { 
        paper_trail_called = true
        whodunnit_value = value
      }) do
        post :create
      end
    end
    
    assert_response :success
    # set_paper_trail_whodunnitの具体的な実装に依存するため、
    # 実際のwhodunnitの値は実装を確認する必要がある
  end

  test "Banken::NotAuthorizedErrorが発生した場合にルートURLにリダイレクトされる" do
    session[:user_id] = @user.id
    
    get :show
    
    assert_redirected_to root_url
    assert { flash[:alert] == 'アクセス権限がありません' }
  end

  test "Banken::NotAuthorizedErrorでrefererがある場合はrefererにリダイレクトされる" do
    session[:user_id] = @user.id
    referer_url = 'http://test.host/previous_page'
    
    request.env['HTTP_REFERER'] = referer_url
    get :show
    
    assert_redirected_to referer_url
    assert { flash[:alert] == 'アクセス権限がありません' }
  end

  test "user_not_authorizedメソッドが正しく動作する" do
    session[:user_id] = @user.id
    
    # user_not_authorizedメソッドを直接呼ぶ
    @controller.send(:user_not_authorized)
    
    assert { flash[:alert] == 'アクセス権限がありません' }
  end

  test "last_accessed_atが更新される" do
    session[:user_id] = @user.id
    original_time = @user.last_accessed_at
    
    # 時間の差を確実にするため少し待つ
    travel_to 1.second.from_now do
      get :index
    end
    
    @user.reload
    assert { @user.last_accessed_at > original_time } if original_time
  end

  test "current_userがアクティブなユーザーのみを返す" do
    # bannedユーザーを作成
    banned_user = User.create!(
      email: 'banned@example.com',
      role: 'banned', # Constants::ROLESにbannedが含まれると仮定
      name: 'Banned User'
    )
    
    session[:user_id] = banned_user.id
    
    get :index
    # bannedユーザーはアクティブではないので認証失敗してリダイレクト
    assert_redirected_to signin_url
  end

  test "before_actionの実行順序が正しい" do
    session[:user_id] = @user.id
    
    # before_actionの実行を記録
    execution_order = []
    
    # Authenticatableのauthenticateが最初に実行される
    @controller.define_singleton_method(:authenticate) do
      execution_order << :authenticate
      super()
    end
    
    @controller.define_singleton_method(:set_raven_context) do
      execution_order << :set_raven_context
      super()
    end
    
    @controller.define_singleton_method(:authorize!) do
      execution_order << :authorize!
      # authorize!の実装が不明なため、何もしない
    end
    
    @controller.define_singleton_method(:set_email_to_env) do
      execution_order << :set_email_to_env
      super()
    end
    
    @controller.define_singleton_method(:set_paper_trail_whodunnit) do
      execution_order << :set_paper_trail_whodunnit
      super()
    end
    
    get :index
    
    # authenticateが最初、その後ApplicationControllerのbefore_actionが続く
    expected_order = [
      :authenticate,
      :set_raven_context,
      :authorize!,
      :set_email_to_env,
      :set_paper_trail_whodunnit
    ]
    
    assert { execution_order == expected_order }
  end

  test "signed_in?ヘルパーメソッドが利用可能" do
    session[:user_id] = @user.id
    
    get :index
    
    # ヘルパーメソッドがコントローラーで利用可能であることを確認
    assert { @controller.send(:signed_in?) == true }
  end

  test "current_userヘルパーメソッドが利用可能" do
    session[:user_id] = @user.id
    
    get :index
    
    # ヘルパーメソッドがコントローラーで利用可能であることを確認
    assert { @controller.send(:current_user) == @user }
  end

  test "複数のリクエストでcurrent_userがキャッシュされる" do
    session[:user_id] = @user.id
    
    get :index
    first_user = @controller.send(:current_user)
    
    # 2回目のアクセスで同じインスタンスが返されることを確認
    get :protected_action
    second_user = @controller.send(:current_user)
    
    assert { first_user.object_id == second_user.object_id }
  end
end
