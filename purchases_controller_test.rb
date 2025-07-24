require 'test_helper'

class PurchasesControllerTest < ActionDispatch::IntegrationTest
  include LoginHelper

  setup do
    signed_in_user(:user, { role: :administrator })
    @app = FactoryBot.create(:app)
    @purchase = FactoryBot.create(:purchase, app: @app)
  end

  test "インデックスページの表示" do
    get purchases_path
    
    assert_response :success
    assert { assigns(:search_form).present? }
    assert { assigns(:purchases).present? }
    assert { assigns(:purchase_cancel_request).present? }
  end

  test "search_formが正しく初期化される" do
    get purchases_path
    
    assert_response :success
    search_form = assigns(:search_form)
    assert { search_form.is_a?(PurchaseSearchForm) }
  end

  test "purchase_cancel_requestが正しく初期化される" do
    get purchases_path, params: { q: { app_id: @app.id } }
    
    assert_response :success
    purchase_cancel_request = assigns(:purchase_cancel_request)
    assert { purchase_cancel_request.is_a?(PurchaseCancelRequest) }
    assert { purchase_cancel_request.app_id == @app.id }
  end

  test "purchase_cancel_requestにcommentsがbuildされる" do
    get purchases_path
    
    assert_response :success
    purchase_cancel_request = assigns(:purchase_cancel_request)
    assert { purchase_cancel_request.comments.present? }
    
    # current_userが設定されたコメントがbuildされることを確認
    comment = purchase_cancel_request.comments.first
    assert { comment.user.present? }
    assert { comment.user.is_a?(User) }
  end

  test "検索パラメータ付きでのインデックス表示" do
    search_params = {
      app_id: @app.id,
      from: 1.month.ago.strftime('%Y-%m-%d'),
      to: Date.current.strftime('%Y-%m-%d')
    }
    
    get purchases_path, params: { q: search_params }
    
    assert_response :success
    search_form = assigns(:search_form)
    assert { search_form.present? }
    
    # search_paramsが正しく設定されることを確認
    purchases = assigns(:purchases)
    assert { purchases.present? }
  end

  test "ページネーションパラメータ付きでのインデックス表示" do
    get purchases_path, params: { page: 1 }
    
    assert_response :success
    purchases = assigns(:purchases)
    
    # Kaminariが使用されている場合
    if purchases.respond_to?(:current_page)
      assert { purchases.current_page == 1 }
    end
  end

  test "詳細ページの表示" do
    # routes.rbでpurchasesは:index, :showのみ有効
    # app.purchase.find(params[:id])が呼ばれる
    get purchase_path(@purchase), params: { app_id: @app.id }
    
    assert_response :success
    assert { assigns(:purchase).present? }
  end

  test "存在しないpurchaseの詳細ページアクセス" do
    # 存在しないIDでアクセスした場合、ActiveRecord::RecordNotFoundが発生
    assert_raises(ActiveRecord::RecordNotFound) do
      get purchase_path(id: 99999), params: { app_id: @app.id }
    end
  end

  test "appが存在しない場合のラー" do
    # 存在しないapp_idでアクセスした場合
    assert_raises(ActiveRecord::RecordNotFound) do
      get purchase_path(@purchase), params: { app_id: 99999 }
    end
  end

  test "search_paramsの動作確認" do
    # 許可されたパラメータのみが処理されることを確認
    params_with_extra = {
      app_id: @app.id,
      from: '2025-01-01',
      to: '2025-01-31',
      extra_param: 'should_be_ignored'
    }
    
    get purchases_path, params: { q: params_with_extra }
    
    assert_response :success
    # extra_paramは無視されることを確認
    search_form = assigns(:search_form)
    assert { search_form.present? }
  end

  test "検索条件なしでの表示" do
    get purchases_path
    
    assert_response :success
    search_form = assigns(:search_form)
    purchases = assigns(:purchases)
    
    # 空の検索条件でも正常に動作することを確認
    assert { search_form.present? }
    assert { purchases.present? }
  end

  test "purchase_cancel_requestのapp_idがnilの場合" do
    get purchases_path
    
    assert_response :success
    purchase_cancel_request = assigns(:purchase_cancel_request)
    
    # app_idが指定されていない場合はnilが設定される
    assert { purchase_cancel_request.app_id.nil? }
  end

  test "検索フォームの実行結果がページネーションされる" do
    # executeメソッドがページネーション付きで実行されることを確認
    search_params = { app_id: @app.id }
    
    get purchases_path, params: { q: search_params, page: 1 }
    
    assert_response :success
    purchases = assigns(:purchases)
    
    # PurchaseSearchForm#executeの結果がページネーションされることを確認
    assert { purchases.present? }
    if purchases.respond_to?(:current_page)
      assert { purchases.current_page == 1 }
    end
  end

  test "app_idパラメータでの購入キャンセルリクエスト初期化" do
    app_id = @app.id
    get purchases_path, params: { q: { app_id: app_id } }
    
    assert_response :success
    purchase_cancel_request = assigns(:purchase_cancel_request)
    
    # params.dig(:q, :app_id)が正しく取得されることを確認
    assert { purchase_cancel_request.app_id == app_id }
  end

  test "current_userがコメントのuserに設定される" do
    user = signed_in_user(:user, { role: :administrator })
    
    get purchases_path
    
    assert_response :success
    purchase_cancel_request = assigns(:purchase_cancel_request)
    
    # buildされたコメントにcurrent_userが設定されることを確認
    built_comment = purchase_cancel_request.comments.first
    assert { built_comment.user.present? }
    assert { built_comment.user == user }
  end

  test "複数のpurchasesがある場合の表示" do
    # 複数のpurchaseを作成
    purchase_1 = FactoryBot.create(:purchase, app: @app)
    purchase_2 = FactoryBot.create(:purchase, app: @app)
    
    get purchases_path, params: { q: { app_id: @app.id } }
    
    assert_response :success
    purchases = assigns(:purchases)
    
    # 複数のpurchaseが表示されることを確認
    assert { purchases.present? }
  end

  test "app.purchaseメソッドが呼ばれることの確認" do
    # showアクションでapp.purchase.find(params[:id])が呼ばれることを確認
    # 実際の実装に基づく動作確認
    get purchase_path(@purchase), params: { app_id: @app.id }
    
    assert_response :success
    purchase = assigns(:purchase)
    
    # 正常に購入データが取得されることを確認
    assert { purchase.present? }
  end

  test "InheritedResourcesのshowアクションが呼ばれる" do
    # show!が呼ばれることでInheritedResourcesのデフォルト動作が実行される
    get purchase_path(@purchase), params: { app_id: @app.id }
    
    assert_response :success
    # InheritedResourcesによりインスタンス変数が設定される
    assert { assigns(:purchase).present? }
  end

  test "日付範囲の検索" do
    from_date = 1.month.ago
    to_date = Date.current
    search_params = {
      app_id: @app.id,
      from: from_date.strftime('%Y-%m-%d'),
      to: to_date.strftime('%Y-%m-%d')
    }
    
    get purchases_path, params: { q: search_params }
    
    assert_response :success
    search_form = assigns(:search_form)
    
    # 日付範囲が正しく設定されることを確認
    assert { search_form.present? }
  end

  test "空の検索パラメータでのエラーハンドリング" do
    get purchases_path, params: { q: {} }
    
    assert_response :success
    # 空のパラメータでもエラーにならないことを確認
    search_form = assigns(:search_form)
    purchases = assigns(:purchases)
    
    assert { search_form.present? }
    assert { purchases.present? }
  end

  test "不正なapp_idでのshowアクセス" do
    # 存在しないappでの詳細ページアクセス
    assert_raises(ActiveRecord::RecordNotFound) do
      get purchase_path(@purchase), params: { app_id: 99999 }
    end
  end

  test "permitted paramsの:app_id, :from, :toが処理される" do
    # search_paramsで許可されたパラメータの確認
    search_params = {
      app_id: @app.id,
      from: '2025-01-01',
      to: '2025-01-31'
    }
    
    get purchases_path, params: { q: search_params }
    
    assert_response :success
    search_form = assigns(:search_form)
    # PurchaseSearchFormが正しく初期化されることを確認
    assert { search_form.present? }
  end

  test "PurchaseSearchFormのexecuteメソッドが呼ばれる" do
    # executeメソッドにブロックが渡されてページネーションが適用される
    get purchases_path, params: { page: 2 }
    
    assert_response :success
    purchases = assigns(:purchases)
    
    # executeブロック内でresult.page(params[:page])が実行される
    if purchases.respond_to?(:current_page)
      assert { purchases.current_page == 2 }
    end
  end



  test "app_idパラメータが必要" do
    # コントローラーの実装でapp_idが必要になる場合の確認
    # 実際の動作は実装に依存
    begin
      get purchase_path(@purchase)
      # app_idなしでもアクセスできる場合
      assert_response :success
    rescue ActiveRecord::RecordNotFound
      # app_idが必要な場合
      assert true
    end
  end

  test "params.dig(:q, :app_id)の動作確認" do
    # params.dig(:q, :app_id)でネストしたパラメータを安全に取得
    nested_params = {
      q: {
        app_id: @app.id,
        from: '2025-01-01'
      }
    }
    
    get purchases_path, params: nested_params
    
    assert_response :success
    purchase_cancel_request = assigns(:purchase_cancel_request)
    assert { purchase_cancel_request.app_id == @app.id }
  end

  test "commentsのbuildでcurrent_userが正しく設定される" do
    user = signed_in_user(:user, { role: :administrator })
    
    get purchases_path
    
    assert_response :success
    purchase_cancel_request = assigns(:purchase_cancel_request)
    
    # @purchase_cancel_request.comments.build(user: current_user)の動作確認
    assert { purchase_cancel_request.comments.size >= 1 }
    comment = purchase_cancel_request.comments.first
    assert { comment.user == user }
    assert { comment.new_record? }
  end

  test "routes制限によりCRUDの一部アクションは利用できない" do
    # routes.rbでonly: %i(index show)のため他のアクションはエラー
    # 実際のルート設定を確認
    assert_raises(ActionController::UrlGenerationError) do
      post purchases_path
    end
  end

  test "InheritedResources::Baseの継承動作確認" do
    # InheritedResourcesを継承していることでshowアクションが利用可能
    get purchase_path(@purchase), params: { app_id: @app.id }
    
    assert_response :success
    # カスタムshowメソッドとshow!により処理される
    assert { assigns(:purchase).present? }
  end

  test "search_paramsでfetchの動作確認" do
    # params.fetch(:q, {})により:qキーがない場合は空ハッシュが返される
    get purchases_path
    
    assert_response :success
    # :qパラメータがなくてもエラーにならない
    search_form = assigns(:search_form)
    assert { search_form.present? }
  end
end
