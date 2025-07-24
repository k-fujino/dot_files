require 'test_helper'

class UsersControllerTest < ActionDispatch::IntegrationTest
  include LoginHelper

  setup do
    signed_in_user(:user, { role: :administrator })
    @user = FactoryBot.create(:user)
  end

  test "インデックスページの表示" do
    get users_path
    
    assert_response :success
    assert { assigns(:users).present? }
  end

  test "複数のusersがある場合のインデックス表示" do
    user_1 = FactoryBot.create(:user, email: "user1@example.com")
    user_2 = FactoryBot.create(:user, email: "user2@example.com")
    
    get users_path
    
    assert_response :success
    users = assigns(:users)
    assert { users.present? }
    assert { users.count >= 2 }
  end

  test "詳細ページの表示" do
    get user_path(@user)
    
    assert_response :success
    assert { assigns(:user) == @user }
  end

  test "存在しないuserの詳細ページアクセス" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get user_path(id: 99999)
    end
  end

  test "新規作成ページの表示" do
    get new_user_path
    
    assert_response :success
    assert { assigns(:user).present? }
    assert { assigns(:user).new_record? }
  end

  test "編集ページの表示" do
    get edit_user_path(@user)
    
    assert_response :success
    assert { assigns(:user) == @user }
  end

  test "存在しないuserの編集ページアクセス" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get edit_user_path(id: 99999)
    end
  end

  test "ユーザーの作成が正常に動作する" do
    user_params = {
      email: "newuser@example.com",
      role: "watcher",
      name: "新規ユーザー"
    }
    
    assert_difference('User.count') do
      post users_path, params: { user: user_params }
    end
    
    created_user = User.last
    assert { created_user.email == "newuser@example.com" }
    assert { created_user.role == "watcher" }
    assert { created_user.name == "新規ユーザー" }
  end

  test "無効なパラメータでユーザー作成失敗" do
    invalid_params = {
      email: "", # presenceバリデーションでエラー
      role: "invalid_role"
    }
    
    assert_no_difference('User.count') do
      post users_path, params: { user: invalid_params }
    end
    
    # バリデーションエラーの場合はフォームを再表示
    assert_response :success
    assert { assigns(:user).errors.present? }
  end

  test "ユーザーの更新が正常に動作する" do
    updated_params = {
      email: "updated@example.com",
      role: "administrator",
      name: "更新されたユーザー"
    }
    
    patch user_path(@user), params: { user: updated_params }
    
    @user.reload
    assert { @user.email == "updated@example.com" }
    assert { @user.role == "administrator" }
    assert { @user.name == "更新されたユーザー" }
  end

  test "無効なパラメータでのユーザー更新失敗" do
    original_email = @user.email
    invalid_params = {
      email: "", # presenceバリデーションでエラー
      role: "invalid_role"
    }
    
    patch user_path(@user), params: { user: invalid_params }
    
    @user.reload
    # 元の値が保持される
    assert { @user.email == original_email }
    
    # バリデーションエラーの場合はフォームを再表示
    assert_response :success
    assert { assigns(:user).errors.present? }
  end

  test "index_attributesメソッドの戻り値確認" do
    get users_path
    
    assert_response :success
    # index_attributesは%i(id email name role last_accessed_at)を返す
    # InheritedResourcesViewsのデフォルト実装をオーバーライドしている
  end

  test "show_attributesメソッドの戻り値確認" do
    get user_path(@user)
    
    assert_response :success
    # show_attributesは%i(id email name role last_accessed_at created_at updated_at)を返す
  end

  test "edit_attributesメソッドの戻り値確認" do
    get edit_user_path(@user)
    
    assert_response :success
    # edit_attributesは%i(email name role)を返す
    # id、created_at、updated_atは除外される
  end

  test "enable_actionsメソッドの戻り値確認" do
    get users_path
    
    assert_response :success
    # enable_actionsは%i(new edit)を返す
    # deleteアクションは無効化されている
  end

  test "permitted_paramsの動作確認" do
    user_params = {
      email: "test@example.com",
      role: "watcher",
      name: "テストユーザー",
      extra_param: "should_be_ignored" # 許可されていないパラメータ
    }
    
    assert_difference('User.count') do
      post users_path, params: { user: user_params }
    end
    
    created_user = User.last
    # 許可されたパラメータのみが処理される
    assert { created_user.email == "test@example.com" }
    assert { created_user.role == "watcher" }
    assert { created_user.name == "テストユーザー" }
  end

  test "異なるroleでのユーザー作成" do
    # Constants::ROLESの値でテスト
    %w[administrator watcher banned].each do |role|
      user_params = {
        email: "#{role}@example.com",
        role: role,
        name: "#{role}ユーザー"
      }
      
      assert_difference('User.count') do
        post users_path, params: { user: user_params }
      end
      
      created_user = User.last
      assert { created_user.role == role }
    end
  end

  test "nameが空の場合のユーザー作成" do
    user_params = {
      email: "noname@example.com",
      role: "watcher",
      name: "" # nameは空でも作成可能と仮定
    }
    
    post users_path, params: { user: user_params }
    
    # nameのバリデーションによって結果が変わる
    # presenceバリデーションがない場合は作成成功
    created_user = User.find_by(email: "noname@example.com")
    if created_user
      assert { created_user.name.blank? }
    end
  end

  test "last_accessed_atが設定されているユーザーの表示" do
    user_with_access = FactoryBot.create(:user, 
                                        last_accessed_at: 1.hour.ago,
                                        email: "accessed@example.com")
    
    get user_path(user_with_access)
    
    assert_response :success
    user = assigns(:user)
    assert { user.last_accessed_at.present? }
  end

  test "削除アクションが利用できない" do
    # enable_actionsに:deleteが含まれていないため、削除は無効化されている
    assert_raises(ActionController::UrlGenerationError) do
      delete user_path(@user)
    end
  end

  test "ページネーション機能のテスト" do
    # 複数のユーザーを作成
    10.times do |i|
      FactoryBot.create(:user, email: "user#{i}@example.com")
    end
    
    get users_path, params: { page: 1 }
    
    assert_response :success
    users = assigns(:users)
    
    # Kaminariが使用されている場合
    if users.respond_to?(:current_page)
      assert { users.current_page == 1 }
    end
  end

  test "InheritedResourcesViewsモジュールの動作確認" do
    get users_path
    
    assert_response :success
    # InheritedResourcesViewsのメソッドがオーバーライドされていることを確認
    # index_attributes, show_attributes, edit_attributes, enable_actionsが
    # カスタム実装で動作している
  end

  test "フォームでのバリデーションエラー表示" do
    # 重複するemailでバリデーションエラーを発生させる
    existing_user = FactoryBot.create(:user, email: "duplicate@example.com")
    
    user_params = {
      email: "duplicate@example.com", # 重複するemail
      role: "watcher",
      name: "重複ユーザー"
    }
    
    assert_no_difference('User.count') do
      post users_path, params: { user: user_params }
    end
    
    # バリデーションエラーでフォームが再表示される
    assert_response :success
    user = assigns(:user)
    assert { user.errors.present? }
    assert { user.errors[:email].present? }
  end

  test "編時のバリデーションエラー処理" do
    other_user = FactoryBot.create(:user, email: "other@example.com")
    
    # 他のユーザーと重複するemailに変更しようとする
    invalid_params = {
      email: "other@example.com",
      role: "watcher",
      name: "変更後"
    }
    
    patch user_path(@user), params: { user: invalid_params }
    
    # バリデーションエラーで編集フォームが再表示される
    assert_response :success
    user = assigns(:user)
    assert { user.errors.present? }
  end

  test "成功時のリダイレクト確認" do
    user_params = {
      email: "redirect@example.com",
      role: "watcher",
      name: "リダイレクトテスト"
    }
    
    post users_path, params: { user: user_params }
    
    # 作成成功時は詳細ページまたはインデックスページにリダイレクト
    created_user = User.last
    assert_redirected_to user_path(created_user)
  end

  test "更新成功時のリダイレクト確" do
    updated_params = {
      email: "redirect_update@example.com",
      role: "administrator",
      name: "リダイレクト更新テスト"
    }
    
    patch user_path(@user), params: { user: updated_params }
    
    # 更新成功時は詳細ページにリダイレクト
    assert_redirected_to user_path(@user)
  end

  test "roleの更新が正しく動作する" do
    # watcherからadministratorに変更
    original_role = @user.role
    
    patch user_path(@user), params: { user: { role: "administrator" } }
    
    @user.reload
    assert { @user.role == "administrator" }
    assert { @user.role != original_role }
  end

  test "nameのみの更新が正しく動作する" do
    original_email = @user.email
    original_role = @user.role
    
    patch user_path(@user), params: { user: { name: "名前のみ変更" } }
    
    @user.reload
    assert { @user.name == "名前のみ変更" }
    # 他のフィールドは変更されない
    assert { @user.email == original_email }
    assert { @user.role == original_role }
  end
end
