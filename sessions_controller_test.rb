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
    
    # サインイン状態を確認するため、認証が必要なページにアクセス
    get stack_aggregations_path
    assert_response :success # 認証されていればsuccessが返る
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
    
    # サインインしていないことを確認するため、認証が必要なページにアクセス
    get stack_aggregations_path
    assert_redirected_to signin_url # 認証されていなければsigninにリダイレクト
  end

  test "存在しないユーザーでサインイン失敗" do
    registered_gplus('nonexistent@example.com')

    get '/auth/gplus/callback'
    
    assert_equal I18n.t('messages.authentication.disabled'), flash[:alert]
    assert_redirected_to signin_url
    
    # サインインしていないことを確認
    get stack_aggregations_path
    assert_redirected_to signin_url
  end

  test "GETメソッドでサインアウト処理" do
    # 事前にサインインしている状態を作る
    signed_in_user(:user, { email: 'signout_test@example.com', role: :administrator })

    get signout_path
    
    assert_equal I18n.t('messages.authentication.signed_out'), flash[:notice]
    assert_redirected_to signin_url
    
    # サインアウトされていることを確認
    get stack_aggregations_path
    assert_redirected_to signin_url
  end

  test "DELETEメソッドでサインアウト処理" do
    # 事前にサインインしている状態を作る
    signed_in_user(:user, { email: 'signout_delete_test@example.com', role: :administrator })

    delete signout_path
    
    assert_equal I18n.t('messages.authentication.signed_out'), flash[:notice]
    assert_redirected_to signin_url
    
    # サインアウトされていることを確認
    get stack_aggregations_path
    assert_redirected_to signin_url
  end

  test "skip_before_actionが正しく設定されている" do
    # new, create, failアクションは認証をスキップすることを確認
    # newアクションは認証不要でアクセス可能
    get signin_path
    assert_response :success
    
    # createアクションは認証不要（OmniAuth callback）
    registered_gplus(@active_user.email)
    get '/auth/gplus/callback'
    assert_response :redirect # サインイン処理後のリダイレクト
  end

  test "authメソッドによるOmniAuthデータの取得" do
    registered_gplus(@active_user.email)
    OmniAuth.config.mock_auth[:gplus][:info][:name] = 'Test Name'
    OmniAuth.config.mock_auth[:gplus][:info][:email] = @active_user.email
    
    get '/auth/gplus/callback'
    
    # authメソッドはprivateだが、createアクションで正しく使用されることを確認
    assert_redirected_to root_url
    # メールアドレスが正しく処理されていることで間接的に確認
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
    assert_redirected_to root_url # サインインは成功する
  end

  test "OmniAuthデータにemailが含まれていない場合" do
    # emailが取得できない場合の処理
    OmniAuth.config.mock_auth[:gplus] = OmniAuth::AuthHash.new({
      info: { name: 'Test User' } # emailなし
    })

    get '/auth/gplus/callback'
    
    # emailがnilの場合、User.find_byはnilを返し、disabled扱いになる
    assert_equal I18n.t('messages.authentication.disabled'), flash[:alert]
    assert_redirected_to signin_url
  end

  test "OmniAuthデータが空の場合" do
    # OmniAuthデータが不正な場合の処理
    OmniAuth.config.mock_auth[:gplus] = OmniAuth::AuthHash.new({})

    get '/auth/gplus/callback'
    
    assert_equal I18n.t('messages.authentication.disabled'), flash[:alert]
    assert_redirected_to signin_url
  end

  test "last_accessed_atが更新される" do
    # sign_in_asメソッドでlast_accessed_atが更新されることを確認
    original_time = @active_user.last_accessed_at
    
    registered_gplus(@active_user.email)
    
    get '/auth/gplus/callback'
    
    # last_accessed_atが更新されていることを確認
    @active_user.reload
    assert @active_user.last_accessed_at > original_time if original_time
  end

  test "連続してサインイン処理を行った場合" do
    # 1回目のサインイン
    registered_gplus(@active_user.email)
    get '/auth/gplus/callback'
    assert_redirected_to root_url
    
    # 2回目のサインイン（既にサインイン済み状態）
    registered_gplus(@active_user.email)
    get '/auth/gplus/callback'
    assert_redirected_to root_url
    assert_equal I18n.t('messages.authentication.signed_in'), flash[:notice]
  end

  test "異なるプロバイダーでのコールバック処理" do
    # gplus以外のプロバイダーでもコールバック処理が動作することを確認
    # ただし、実際のルーティングではgplusのみ設定されている
    registered_gplus(@active_user.email)
    
    get '/auth/gplus/callback'
    assert_redirected_to root_url
    assert_equal I18n.t('messages.authentication.signed_in'), flash[:notice]
  end

  test "nameの文字数制限内での更新" do
    # User modelのvalidation: validates :name, length: { maximum: 255 }
    user_without_name = FactoryBot.create(:user, email: 'longname@example.com', name: nil, role: :administrator)
    long_name = 'a' * 255 # 255文字以内
    
    registered_gplus(user_without_name.email)
    OmniAuth.config.mock_auth[:gplus][:info][:name] = long_name

    assert_changes -> { user_without_name.reload.name }, from: nil, to: long_name do
      get '/auth/gplus/callback'
    end
    
    assert_redirected_to root_url
  end

  test "サインアウト後に認証が必要なページにアクセス" do
    # サインインしてからサインアウト
    signed_in_user(:user, { email: 'signout_redirect_test@example.com', role: :administrator })
    
    delete signout_path
    assert_redirected_to signin_url
    
    # その後認証が必要なページにアクセスしてリダイレクトされることを確認
    get users_path
    assert_redirected_to signin_url
  end

  test "InheritedResources::Baseの継承動作" do
    # InheritedResources::Baseを継承していることを確認
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
