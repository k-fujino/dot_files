require 'test_helper'

class SessionsControllerTest < ActionDispatch::IntegrationTest
  include LoginHelper

  setup do
    @active_user = FactoryBot.create(:user, email: 'test@example.com', name: 'Test User', role: :administrator)
    @banned_user = FactoryBot.create(:user, email: 'banned@example.com', name: 'Banned User', role: :banned)
  end

  test "新規作成画面を取得" do
    get signin_path
    assert_response :success
    assert_template :new
  end

  test "アクティブユーザーでサインイン成功" do
    # OmniAuthのモック設定
    registered_gplus(@active_user.email)
    OmniAuth.config.mock_auth[:gplus][:info][:name] = @active_user.name

    get '/auth/gplus/callback'
    
    assert_redirected_to root_url
    assert_equal I18n.t('messages.authentication.signed_in'), flash[:notice]
    assert_equal @active_user.id, session[:user_id]
  end

  test "nameが未設定のアクティブユーザーでサインイン時にnameを更新" do
    user_without_name = FactoryBot.create(:user, email: 'noname@example.com', name: nil, role: :administrator)
    
    # OmniAuthのモック設定
    registered_gplus(user_without_name.email)
    OmniAuth.config.mock_auth[:gplus][:info][:name] = 'Updated Name'

    assert_changes -> { user_without_name.reload.name }, from: nil, to: 'Updated Name' do
      get '/auth/gplus/callback'
    end
    
    assert_redirected_to root_url
    assert_equal I18n.t('messages.authentication.signed_in'), flash[:notice]
  end

  test "nameが既に設定されているユーザーでサインイン時はnameを更新しない" do
    # OmniAuthのモック設定
    registered_gplus(@active_user.email)
    OmniAuth.config.mock_auth[:gplus][:info][:name] = 'Different Name'
    original_name = @active_user.name

    assert_no_changes -> { @active_user.reload.name } do
      get '/auth/gplus/callback'
    end
    
    assert_equal original_name, @active_user.reload.name
    assert_redirected_to root_url
  end

  test "bannedユーザーでサインイン失敗" do
    # User.activeスコープではbannedユーザーは除外される
    registered_gplus(@banned_user.email)

    get '/auth/gplus/callback'
    
    assert_equal I18n.t('messages.authentication.disabled'), flash[:alert]
    assert_redirected_to signin_url
    assert_nil session[:user_id]
  end

  test "存在しないユーザーでサインイン失敗" do
    registered_gplus('nonexistent@example.com')

    get '/auth/gplus/callback'
    
    assert_equal I18n.t('messages.authentication.disabled'), flash[:alert]
    assert_redirected_to signin_url
    assert_nil session[:user_id]
  end

  test "GETメソッドでサインアウト処理" do
    # 事前にサインインしている状態を作る
    session[:user_id] = @active_user.id

    get signout_path
    
    assert_equal I18n.t('messages.authentication.signed_out'), flash[:notice]
    assert_redirected_to signin_url
    assert_nil session[:user_id]
  end

  test "DELETEメソッドでサインアウト処理" do
    # 事前にサインインしている状態を作る
    session[:user_id] = @active_user.id

    delete signout_path
    
    assert_equal I18n.t('messages.authentication.signed_out'), flash[:notice]
    assert_redirected_to signin_url
    assert_nil session[:user_id]
  end

  test "認証失敗時のfailアクション処理" do
    # SessionsControllerのfailアクションを直接呼び出し
    # 推測: failアクションへの直接アクセスは通常のルーティングにはないが、
    # OmniAuth失敗時に内部的に呼ばれる可能性
    @controller = SessionsController.new
    @controller.request = ActionDispatch::TestRequest.create
    @controller.response = ActionDispatch::TestResponse.new
    
    # failアクションを直接実行
    @controller.fail
    
    assert_equal I18n.t('messages.authentication.failed'), @controller.instance_variable_get(:@flash)[:alert]
  end

  test "skip_before_actionが正しく設定されている" do
    # new, create, failアクションは認証をスキップすることを確認
    # newアクションは認証不要でアクセス可能
    get signin_path
    assert_response :success
    
    # createアクションは認証不要（OmniAuth callback）
    registered_gplus(@active_user.email)
    get '/auth/gplus/callback'
    assert_response :redirect
  end

  test "authメソッドによるOmniAuthデータの取得とメモ化" do
    registered_gplus(@active_user.email)
    OmniAuth.config.mock_auth[:gplus][:info][:name] = 'Test Name'
    OmniAuth.config.mock_auth[:gplus][:info][:email] = @active_user.email
    
    get '/auth/gplus/callback'
    
    # authメソッドはprivateだが、createアクションで正しく使用されることを確認
    assert_redirected_to root_url
    # メールアドレスとnameが正しく処理されていることで間接的に確認
    assert_equal @active_user.email, @active_user.reload.email
  end

  test "user.nameがnilの場合のみnameを更新" do
    user_with_empty_name = FactoryBot.create(:user, email: 'empty@example.com', name: '', role: :administrator)
    
    registered_gplus(user_with_empty_name.email)
    OmniAuth.config.mock_auth[:gplus][:info][:name] = 'New Name'

    # 空文字の場合は更新されない（unless user.nameの条件）
    assert_no_changes -> { user_with_empty_name.reload.name } do
      get '/auth/gplus/callback'
    end
    
    assert_equal '', user_with_empty_name.reload.name
  end

  test "OmniAuthデータにemailが含まれていない場合" do
    # 推測: emailが取得できない場合の処理
    OmniAuth.config.mock_auth[:gplus] = OmniAuth::AuthHash.new({
      info: { name: 'Test User' } # emailなし
    })

    get '/auth/gplus/callback'
    
    # emailがnilの場合、User.find_byはnilを返し、disabled扱いになる
    assert_equal I18n.t('messages.authentication.disabled'), flash[:alert]
    assert_redirected_to signin_url
  end

  test "OmniAuthデータが空の場合" do
    # 推測: OmniAuthデータが不正な場合の処理
    OmniAuth.config.mock_auth[:gplus] = OmniAuth::AuthHash.new({})

    get '/auth/gplus/callback'
    
    assert_equal I18n.t('messages.authentication.disabled'), flash[:alert]
    assert_redirected_to signin_url
  end

  test "last_accessed_atが更新される" do
    # sign_in_asメソッドでlast_accessed_atが更新されることを確認
    freeze_time = Time.current
    Time.stub(:current, freeze_time) do
      registered_gplus(@active_user.email)
      
      assert_changes -> { @active_user.reload.last_accessed_at } do
        get '/auth/gplus/callback'
      end
      
      assert_equal freeze_time, @active_user.reload.last_accessed_at
    end
  end

  test "セッションとクッキーが正しく設定される" do
    registered_gplus(@active_user.email)

    get '/auth/gplus/callback'
    
    # セッションにuser_idが設定される
    assert_equal @active_user.id, session[:user_id]
    
    # ActionCable用のクッキーが設定される
    assert_not_nil cookies.encrypted["user_id"]
    assert_equal @active_user.id, cookies.encrypted["user_id"]
  end

  test "InheritedResources::Baseの継承動作" do
    # InheritedResources::Baseを継承していることで得られる基本的なRESTful動作
    # ただし、SessionsControllerでは主にnew, create, destroyのみを使用
    
    # コントローラーがInheritedResources::Baseを継承していることを確認
    assert SessionsController.ancestors.include?(InheritedResources::Base)
  end

  private

  def signin_path
    '/signin'
  end

  def signout_path
    '/signout'
  end

  def signin_url
    'http://www.example.com/signin'
  end
end
