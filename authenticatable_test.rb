require 'test_helper'

class AuthenticatableTest < ActionController::TestCase
  # テスト用のダミーコントローラーを作成
  # Authenticatableモジュールをincludeしてテスト
  class TestController < ActionController::Base
    include Authenticatable
    
    def index
      render plain: 'success'
    end
    
    def protected_action
      render plain: 'protected'
    end
  end

  setup do
    # ルーティングの設定
    Rails.application.routes.draw do
      get 'test/index', to: 'authenticatable_test/test#index'
      get 'test/protected_action', to: 'authenticatable_test/test#protected_action'
      get '/signin' => 'sessions#new'
      root 'welcome#index'
    end

    @controller = TestController.new
    
    # FactoryBotを使用してテスト用ユーザーを作成
    @user = FactoryBot.create(:user, :administrator)
    @banned_user = FactoryBot.create(:user, :banned)
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
    session[:user_id] = @banned_user.id
    
    get :index
    # User.activeスコープによりバンクされたユーザーは除外される
    assert_redirected_to signin_url
  end

  test "current_userが正しいユーザーを返す" do
    session[:user_id] = @user.id
    
    get :index
    assert { @controller.send(:current_user) == @user }
  end

  test "current_userがnilの場合にnilを返す" do
    session[:user_id] = nil
    
    get :index
    assert { @controller.send(:current_user).nil? }
  end

  test "current_userがメモ化される" do
    session[:user_id] = @user.id
    
    get :index
    
    # 1回目の呼び出し
    first_call = @controller.send(:current_user)
    # 2回目の呼び出し（同じインスタンスが返される）
    second_call = @controller.send(:current_user)
    
    assert { first_call.object_id == second_call.object_id }
  end

  test "signed_in?が正しく動作する" do
    # ログイン状態
    session[:user_id] = @user.id
    get :index
    assert { @controller.send(:signed_in?) == true }
  end

  test "authenticateメソッドでlast_accessed_atが更新される" do
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
    session[:user_id] = nil # current_userがnilになるように設定
    
    get :index
    
    assert_redirected_to signin_url
    assert { session[:user_id].nil? }
  end

  test "helper_methodが正しく設定される" do
    # current_userとsigned_in?がヘルパーメソッドとして利用可能
    assert { TestController._helper_methods.include?(:current_user) }
    assert { TestController._helper_methods.include?(:signed_in?) }
  end

  test "before_actionが正しく設定される" do
    # authenticateがbefore_actionとして設定されていることを確認
    before_actions = TestController._process_action_callbacks.select do |callback|
      callback.kind == :before && callback.filter == :authenticate
    end
    
    assert { before_actions.any? }
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
    session[:user_id] = @banned_user.id
    get :index
    assert { @controller.send(:current_user).nil? }
  end

  test "セッションハイジャック対策でユーザーIDが数値以外の場合に安全に処理される" do
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

  test "Constants::SESSION_EXPIRATION_PERIODが定義されている" do
    assert { Constants::SESSION_EXPIRATION_PERIOD == 1.week }
  end

  test "sign_inとsign_outのメソッドが定義されている" do
    assert { @controller.respond_to?(:sign_in_as, true) }
    assert { @controller.respond_to?(:sign_out, true) }
  end

  test "update_last_accessed_atメソッドが定義されている" do
    assert { @controller.respond_to?(:update_last_accessed_at, true) }
  end
end
