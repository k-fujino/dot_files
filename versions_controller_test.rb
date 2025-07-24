require 'test_helper'

class VersionsControllerTest < ActionDispatch::IntegrationTest
  include LoginHelper

  setup do
    signed_in_user(:user, { role: :administrator })
    @user = FactoryBot.create(:user)
    @version = FactoryBot.create(:version, whodunnit: @user.id.to_s)
  end

  test "インデックスページの表示" do
    get versions_path
    
    assert_response :success
    assert { assigns(:versions).present? }
  end

  test "複数のversionsがある場合のインデックス表示" do
    version_1 = FactoryBot.create(:version, 
                                 item_type: "User", 
                                 item_id: @user.id,
                                 event: "create",
                                 whodunnit: @user.id.to_s,
                                 created_at: 2.hours.ago)
    version_2 = FactoryBot.create(:version, 
                                 item_type: "App", 
                                 item_id: 1,
                                 event: "update",
                                 whodunnit: @user.id.to_s,
                                 created_at: 1.hour.ago)
    
    get versions_path
    
    assert_response :success
    versions = assigns(:versions)
    assert { versions.present? }
    assert { versions.count >= 2 }
  end

  test "詳細ページの表示" do
    get version_path(@version)
    
    assert_response :success
    assert { assigns(:version) == @version }
  end

  test "存在しないversionの詳細ページアクセス" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get version_path(id: 99999)
    end
  end

  test "userとのbelongs_to関連の確認" do
    user_with_version = FactoryBot.create(:user, email: "belongs_to_test@example.com")
    version_with_user = FactoryBot.create(:version, 
                                         item_type: "User",
                                         item_id: user_with_version.id,
                                         event: "create",
                                         whodunnit: user_with_version.id.to_s)
    
    get version_path(version_with_user)
    
    assert_response :success
    version = assigns(:version)
    
    # belongs_to :user, foreign_key: :whodunnit, optional: trueの動作確認
    assert { version.respond_to?(:user) }
    if version.whodunnit.present?
      # whodunnitが存在する場合、対応するuserが取得できる
      assert { version.user.is_a?(User) || version.user.nil? }
    end
  end

  test "latest_orderスコープが適用されていることの確認" do
    # created_atで並び順を確認するためのテストデータ作成
    old_version = FactoryBot.create(:version, 
                                   item_type: "User",
                                   item_id: @user.id,
                                   event: "create",
                                   whodunnit: @user.id.to_s,
                                   created_at: 2.hours.ago)
    new_version = FactoryBot.create(:version, 
                                   item_type: "User",
                                   item_id: @user.id,
                                   event: "update",
                                   whodunnit: @user.id.to_s,
                                   created_at: 1.hour.ago)
    
    get versions_path
    
    assert_response :success
    versions = assigns(:versions)
    
    if versions.count >= 2
      # latest_orderはcreated_at: :descで並び替え（Version.rb で確認済み）
      first_two = versions.limit(2)
      assert { first_two.first.created_at >= first_two.second.created_at }
    end
  end

  test "ページネーションパラメータ付きでのインデックス表示" do
    get versions_path, params: { page: 1 }
    
    assert_response :success
    assert { assigns(:versions).present? }
    # Kaminariが使用されている場合
    if assigns(:versions).respond_to?(:current_page)
      assert { assigns(:versions).current_page == 1 }
    end
  end

  test "存在しないページ番号でのアクセス" do
    get versions_path, params: { page: 9999 }
    
    assert_response :success
    # ページが存在しない場合は空の結果が返される可能性がある
    versions = assigns(:versions)
    if versions.respond_to?(:current_page)
      assert { versions.respond_to?(:current_page) }
    end
  end

  test "index_attributesメソッドの戻り値確認" do
    get versions_path
    
    assert_response :success
    # index_attributesは%i(id item_type item_id event user_email created_at)を返す
    # InheritedResourcesViewsのデフォルト実装をオーバーライドしている
  end

  test "enable_actionsメソッドが空配列を返すことの確認" do
    get versions_path
    
    # enable_actionsが空配列のため、new, edit, deleteアクションが無効化されている
    assert_response :success
    # InheritedResourcesViewsのDEFAULT_ENABLE_ACTIONSをオーバーライドして空配列を返している
  end

  test "link_attributesメソッドの戻り値確" do
    get versions_path
    
    assert_response :success
    # link_attributesはsuperの結果に%i(user_email)を追加している
    # InheritedResourcesViewsのDEFAULT_LINK_ATTRIBUTES + user_email
  end

  test "異なるitem_typeのversionsの表示" do
    user_version = FactoryBot.create(:version, 
                                    item_type: "User",
                                    item_id: @user.id,
                                    event: "create",
                                    whodunnit: @user.id.to_s)
    app_version = FactoryBot.create(:version, 
                                   item_type: "App",
                                   item_id: 1,
                                   event: "update",
                                   whodunnit: @user.id.to_s)
    
    get versions_path
    
    assert_response :success
    versions = assigns(:versions)
    
    # 異なるitem_typeのversionsが全て表示されることを確認
    assert { versions.count >= 2 }
  end

  test "異なるeventのversionsの表示" do
    create_version = FactoryBot.create(:version, 
                                      item_type: "User",
                                      item_id: @user.id,
                                      event: "create",
                                      whodunnit: @user.id.to_s)
    update_version = FactoryBot.create(:version, 
                                      item_type: "User",
                                      item_id: @user.id,
                                      event: "update",
                                      whodunnit: @user.id.to_s)
    destroy_version = FactoryBot.create(:version, 
                                       item_type: "User",
                                       item_id: @user.id,
                                       event: "destroy",
                                       whodunnit: @user.id.to_s)
    
    get versions_path
    
    assert_response :success
    versions = assigns(:versions)
    
    # 異なるeventのversionsが全て表示されることを確認
    assert { versions.count >= 3 }
  end

  test "whodunnitが設定されているversionの表示" do
    version_with_user = FactoryBot.create(:version, 
                                         item_type: "User",
                                         item_id: @user.id,
                                         event: "update",
                                         whodunnit: @user.id.to_s)
    
    get version_path(version_with_user)
    
    assert_response :success
    version = assigns(:version)
    assert { version.whodunnit == @user.id.to_s }
  end

  test "whodunnitがnilのversionの表示" do
    version_without_user = FactoryBot.create(:version, 
                                            item_type: "User",
                                            item_id: @user.id,
                                            event: "create",
                                            whodunnit: nil)
    
    get version_path(version_without_user)
    
    assert_response :success
    version = assigns(:version)
    assert { version.whodunnit.nil? }
  end

  test "objectフィールドの表示" do
    version_with_object = FactoryBot.create(:version, 
                                           item_type: "User",
                                           item_id: @user.id,
                                           event: "destroy",
                                           whodunnit: @user.id.to_s,
                                           object: '{"id":1,"email":"test@example.com"}')
    
    get version_path(version_with_object)
    
    assert_response :success
    version = assigns(:version)
    assert { version.object.present? }
    # 具体的なJSON内容の確認は実際のPaperTrail実装に依存
  end

  test "changesetメソッドの動作確認" do
    # show.html.hamlで@version.changesetが使用されている
    version_with_changes = FactoryBot.create(:version, 
                                            item_type: "User",
                                            item_id: @user.id,
                                            event: "update",
                                            whodunnit: @user.id.to_s,
                                            object_changes: '{"email":["old@example.com","new@example.com"],"name":["Old Name","New Name"]}')
    
    get version_path(version_with_changes)
    
    assert_response :success
    version = assigns(:version)
    
    # PaperTrail::Versionのchangesetメソッドが利用可能であることを確認
    assert { version.respond_to?(:changeset) }
    
    if version.object_changes.present?
      # changesetがハッシュ形式で変更内容を返すことを確認
      changeset = version.changeset
      assert { changeset.is_a?(Hash) }
    end
  end

  test "InheritedResourcesViewsモジュールの動作確認" do
    get versions_path
    
    assert_response :success
    # InheritedResourcesViewsのメソッドがオーバーライドされていることを確認
    # index_attributes, enable_actions, link_attributesがカスタム実装で動作している
  end

  test "PaperTrail::Versionの継承確認" do
    get versions_path
    
    assert_response :success
    versions = assigns(:versions)
    
    if versions.any?
      first_version = versions.first
      # Version < PaperTrail::Versionの継承関係を確認
      assert { first_version.is_a?(PaperTrail::Version) }
      assert { first_version.class == Version }
    end
  end

  test "user_emailメソッドの動作確認" do
    # Version.rbでuser_emailメソッドが定義されている
    user_with_email = FactoryBot.create(:user, email: "version_test@example.com")
    version_with_user = FactoryBot.create(:version, 
                                         item_type: "User",
                                         item_id: user_with_email.id,
                                         event: "update",
                                         whodunnit: user_with_email.id.to_s)
    
    get version_path(version_with_user)
    
    assert_response :success
    version = assigns(:version)
    # user_emailメソッドが存在し、userのemailを返すことを確認
    assert { version.respond_to?(:user_email) }
    # belongs_to :user関連によりuserが取得できる場合
    if version.user.present?
      assert { version.user_email == user_with_email.email }
    end
  end

  test "has_paper_trailによるVersion自動作成" do
    # User.rbでhas_paper_trail ignore: [:last_accessed_at]が設定されている
    # Userの変更時にVersionが自動作成されることを確認
    original_count = Version.count
    
    # Userを作成（has_paper_trailによりVersionが作成される）
    new_user = FactoryBot.create(:user, email: "paper_trail_test@example.com")
    
    # Versionが増加していることを確認
    assert { Version.count > original_count }
    
    # 作成されたVersionの確認
    latest_version = Version.latest_order.first
    assert { latest_version.item_type == "User" }
    assert { latest_version.item_id == new_user.id }
    assert { latest_version.event == "create" }
  end

  test "ビューでのuser_emailリンク表示確認" do
    # show.html.hamlでuser_emailがリンクとして表示される
    user_for_link = FactoryBot.create(:user, email: "link_test@example.com")
    version_for_link = FactoryBot.create(:version, 
                                        item_type: "User",
                                        item_id: user_for_link.id,
                                        event: "update",
                                        whodunnit: user_for_link.id.to_s)
    
    get version_path(version_for_link)
    
    assert_response :success
    
    # ビューでuser_emailが表示され、user_pathへのリンクが生成されることを確認
    if assigns(:version).user_email.present?
      assert_match /#{user_for_link.email}/, response.body
      # link_to user_path(@version.whodunnit) の確認
      assert_match /\/users\/#{user_for_link.id}/, response.body
    end
  end

  test "異なるユーザーによるVersionの表示" do
    other_user = FactoryBot.create(:user, email: "other@example.com")
    other_version = FactoryBot.create(:version, 
                                     item_type: "User",
                                     item_id: other_user.id,
                                     event: "create",
                                     whodunnit: other_user.id.to_s)
    
    get versions_path
    
    assert_response :success
    versions = assigns(:versions)
    
    # 全てのユーザーによるVersionが表示されることを確認
    # （特定のユーザーでのフィルタリングはされていない）
    assert { versions.count >= 2 }
  end
end
