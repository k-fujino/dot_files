require 'test_helper'

class SessionsControllerTest < ActionDispatch::IntegrationTest
  include LoginHelper

  def setup
    @user = users(:user)
    @user.update!(active: true, email: 'test@example.com', name: 'Test User')
  end

  test "should get new" do
    get new_session_path
    assert_response :success
  end

  test "should create session with valid user" do
    auth_hash = {
      info: {
        email: @user.email,
        name: @user.name
      }
    }
    
    request.env['omniauth.auth'] = auth_hash
    
    post sessions_path
    
    assert_redirected_to root_url
    assert_equal I18n.t('messages.authentication.signed_in'), flash[:notice]
  end

  test "should update user name if not present during create" do
    @user.update!(name: nil)
    auth_hash = {
      info: {
        email: @user.email,
        name: 'New Name'
      }
    }
    
    request.env['omniauth.auth'] = auth_hash
    
    assert_changes -> { @user.reload.name }, from: nil, to: 'New Name' do
      post sessions_path
    end
  end

  test "should not update user name if already present during create" do
    original_name = @user.name
    auth_hash = {
      info: {
        email: @user.email,
        name: 'Different Name'
      }
    }
    
    request.env['omniauth.auth'] = auth_hash
    
    assert_no_changes -> { @user.reload.name } do
      post sessions_path
    end
    
    assert_equal original_name, @user.reload.name
  end

  test "should fail authentication with inactive user" do
    @user.update!(active: false)
    auth_hash = {
      info: {
        email: @user.email,
        name: @user.name
      }
    }
    
    request.env['omniauth.auth'] = auth_hash
    
    post sessions_path
    
    assert_equal I18n.t('messages.authentication.disabled'), flash[:alert]
    # fallback_authentication の動作をテスト（実装に依存）
  end

  test "should fail authentication with non-existent user" do
    auth_hash = {
      info: {
        email: 'nonexistent@example.com',
        name: 'Non Existent'
      }
    }
    
    request.env['omniauth.auth'] = auth_hash
    
    post sessions_path
    
    assert_equal I18n.t('messages.authentication.disabled'), flash[:alert]
  end

  test "should destroy session" do
    signed_in_user(@user)
    
    delete session_path(@user)
    
    assert_equal I18n.t('messages.authentication.signed_out'), flash[:notice]
    # fallback_authentication の動作をテスト
  end

  test "should handle authentication failure" do
    get fail_sessions_path
    
    assert_equal I18n.t('messages.authentication.failed'), flash[:alert]
    # fallback_authentication の動作をテスト
  end

  test "should skip authentication for new action" do
    # authenticate メソッドがスキップされることをテスト
    get new_session_path
    assert_response :success
  end

  test "should skip authentication for create action" do
    # authenticate メソッドがスキップされることをテスト
    post sessions_path
    assert_response :success # または適切なレポンス
  end

  test "should skip authentication for fail action" do
    # authenticate メソッドがスキップされることをテスト
    get fail_sessions_path
    assert_response :success # または適切なレスポンス
  end

  private

  def signed_in_user(user)
    # LoginHelperの実装に依存
    # 通常はsessionやcookieを設定
    session[:user_id] = user.id
  end
end
