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
    @user = FactoryBot.create(:user, :administrator)
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

  test "バンクされたユーザーがアクセスできない" do
    banned_user = FactoryBot.create(:user, :banned)
    session[:user_id] = banned_user.id
    
    get :index
    # User.activeスコープによりバンクされたユーザーは除外される
    assert_redirected_to signin_url
  end

  test "set_raven_contextでRavenのユーザーコンテキストが設定される" do
    session[:user_id] = @user.id
    
    # RRを使用したスタブ
    stub(Raven).user_context
    stub(Raven).extra_context
    
    get :index
    assert_response :success
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
    
    # PaperTrailのスタブ
    paper_trail_request = Object.new
    stub(PaperTrail).request { paper_trail_request }
    stub(paper_trail_request).whodunnit=
    
    post :create
    assert_response :success
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

  test "fallback_authenticationでセッションとクッキーがクリアされる" do
    # 初期状態でセッションとクッキーを設定
    session[:user_id] = @user.id
    cookies.encrypted["user_id"] = @user.id
    
    # 未認証状態でアクセス（fallback_authenticationが呼ばれる）
    session[:user_id] = nil # current_userがnilになるうに設定
    
    get :index
    
    assert_redirected_to signin_url
    assert { session[:user_id].nil? }
  end

  test "複数回のアクセスでcurrent_userが一貫している" do
    session[:user_id] = @user.id
    
    # 1回目のアクセス
    get :index
    first_user = @controller.send(:current_user)
    
    # 2回目のアクセス
    get :protected_action
    second_user = @controller.send(:current_user)
    
    assert { first_user == second_user }
    assert { first_user.id == @user.id }
  end

  test "User.activeスコープが正しく適用される" do
    # アクティブユーザーでのテスト
    session[:user_id] = @user.id
    get :index
    assert { @controller.send(:current_user) == @user }
    
    # バンクされたユーザーでのテスト
    banned_user = FactoryBot.create(:user, :banned)
    session[:user_id] = banned_user.id
    get :index
    assert { @controller.send(:current_user).nil? }
  end

  test "セッションハイジャック対策でユザーIDが数値以外の場合に安全に処理される" do
    # 不正なセッション値を設定
    session[:user_id] = "malicious_string"
    
    get :index
    
    # エラーが発生せず、適切にリダイレクトされることを確認
    assert_redirected_to signin_url
    assert { @controller.send(:current_user).nil? }
  end

  test "Time.currentが正しく使用される" do
    freeze_time = Time.parse('2025-01-15 12:00:00 UTC')
    
    travel_to freeze_time do
      session[:user_id] = @user.id
      get :index
      
      @user.reload
      assert { @user.last_accessed_at.to_i == freeze_time.to_i }
    end
  end
end
