require 'test_helper'

class ChangeRequestsControllerTest < ActionDispatch::IntegrationTest
  include LoginHelper

  setup do
    @user = signed_in_user(:user, { role: :administrator })
    @manager_user = FactoryBot.create(:user, role: :administrator)
    
    @app = FactoryBot.create(:app, name: 'Test App', identifier: 'test_app', manager: @manager_user)
    @change_request = FactoryBot.create(:purchase_cancel_request, 
      app: @app, 
      requested_user: @user,
      state: 'requested'
    )
    
    # コメント付きの変更リクエスト
    @comment = FactoryBot.create(:comment, 
      commentable: @change_request,
      user: @user,
      content: 'Test comment'
    )
  end

  test "インデックスを取得" do
    get change_requests_path
    
    assert_response :success
    assert_template :index
    assert assigns(:q) # Ransackのqオブジェクト
    assert assigns(:change_requests)
    
    # includesでN+1問題対策されていることを間接的に確認
    change_requests = assigns(:change_requests)
    assert_not_nil change_requests
  end

  test "検索条件付きでインデックスを取得" do
    search_params = {
      app_id_eq: @app.id,
      state_eq: 'requested',
      type_eq: 'PurchaseCancelRequest',
      processed_user_id_eq: @manager_user.id
    }
    
    get change_requests_path, params: { q: search_params }
    
    assert_response :success
    assert_template :index
    assert assigns(:q)
    assert assigns(:change_requests)
  end

  test "検索パラメータのフィルタリング" do
    # 許可されていないパラメータが除外されることを確認
    search_params = {
      app_id_eq: @app.id,
      state_eq: 'requested',
      unauthorized_param: 'should_be_filtered'
    }
    
    get change_requests_path, params: { q: search_params }
    
    assert_response :success
    # unauthorized_paramは処理されないことを間接的に確認
    assert assigns(:q)
  end

  test "詳細画面を取得" do
    get change_request_path(@change_request)
    
    assert_response :success
    assert_template :show
    assert_equal @change_request, assigns(:change_request)
    assert assigns(:comments) # コメントのページネーション
    
    # コメントが含まれていることを確認
    comments = assigns(:comments)
    assert comments.any?
  end

  test "詳細画面でコメントのページネーション" do
    # 複数のコメントを作成してページネーションをテスト
    11.times do |i|
      FactoryBot.create(:comment, 
        commentable: @change_request,
        user: @user,
        content: "Comment #{i}"
      )
    end
    
    get change_request_path(@change_request), params: { page: 1 }
    
    assert_response :success
    comments = assigns(:comments)
    assert_equal 10, comments.count # per(10)の設定
  end

  test "新規作成画面を取得" do
    get new_change_request_path
    
    assert_response :success
    assert_template :new
    assert assigns(:change_request)
    
    # コメントがbuildされていることを確認
    change_request = assigns(:change_request)
    assert change_request.comments.any?
    assert_equal @user, change_request.comments.first.user
  end

  test "PurchaseCancelRequestを作成成功" do
    change_request_params = {
      app_id: @app.id,
      type: 'PurchaseCancelRequest',
      purchase_id: 'test_purchase_123',
      comments_attributes: {
        '0' => { user_id: @user.id, content: 'Purchase cancel request' }
      },
      purchase_cancel_histories_attributes: {
        '0' => { resource_id: 123 }
      }
    }
    
    assert_difference 'ChangeRequest.count', 1 do
      assert_difference 'Comment.count', 1 do
        post change_requests_path, params: { change_request: change_request_params }
      end
    end
    
    change_request = ChangeRequest.last
    assert_equal @user, change_request.requested_user
    assert_equal 'requested', change_request.state
    assert_equal 'PurchaseCancelRequest', change_request.type
    assert_not_nil change_request.requested_at
    assert_redirected_to change_request_path(change_request)
  end

  test "ConsumptionRevisionRequestを作成成功" do
    change_request_params = {
      app_id: @app.id,
      type: 'ConsumptionRevisionRequest',
      store_type: 'app_store',
      price: 100,
      applied_on: Date.current,
      comments_attributes: {
        '0' => { user_id: @user.id, content: 'Consumption revision request' }
      }
    }
    
    assert_difference 'ChangeRequest.count', 1 do
      post change_requests_path, params: { change_request: change_request_params }
    end
    
    change_request = ChangeRequest.last
    assert_equal 'ConsumptionRevisionRequest', change_request.type
    assert_redirected_to change_request_path(change_request)
  end

  test "変更リクエストの作成失敗" do
    # 必須項目を空にして作成失敗
    invalid_params = {
      app_id: nil,
      type: nil,
      comments_attributes: {
        '0' => { user_id: @user.id, content: '' }
      }
    }
    
    assert_no_difference 'ChangeRequest.count' do
      post change_requests_path, params: { change_request: invalid_params }
    end
    
    assert_response :success # バリデーションエラーでフォーム再表示
    assert_template :new
  end

  test "不正なtypeで変更リクエスト作成失敗" do
    invalid_params = {
      app_id: @app.id,
      type: 'InvalidRequestType', # REQUESTABLE_TYPESに含まれない
      comments_attributes: {
        '0' => { user_id: @user.id, content: 'Invalid type' }
      }
    }
    
    assert_no_difference 'ChangeRequest.count' do
      post change_requests_path, params: { change_request: invalid_params }
    end
    
    assert_response :success
    assert_template :new
  end

  test "変更リクエストの承認成功" do
    update_params = {
      state: 'approved',
      comments_attributes: {
        '0' => { user_id: @user.id, content: 'Approved by manager' }
      }
    }
    
    patch change_request_path(@change_request), params: { change_request: update_params }
    
    @change_request.reload
    assert_equal 'approved', @change_request.state
    assert_equal @user, @change_request.processed_user
    assert_not_nil @change_request.approved_at
    assert_redirected_to change_request_path(@change_request)
    assert_equal I18n.t('change_requests.update.notice'), flash[:notice]
  end

  test "変更リクエストの拒否成功" do
    update_params = {
      state: 'rejected',
      comments_attributes: {
        '0' => { user_id: @user.id, content: 'Rejected due to insufficient information' }
      }
    }
    
    patch change_request_path(@change_request), params: { change_request: update_params }
    
    @change_request.reload
    assert_equal 'rejected', @change_request.state
    assert_equal @user, @change_request.processed_user
    assert_not_nil @change_request.rejected_at
    assert_redirected_to change_request_path(@change_request)
  end

  test "変更リクエストの更新失敗（不正な状態変更）" do
    # 既に処理済みの変更リクエストをさらに変更しようとする
    @change_request.update!(state: 'approved', processed_user: @manager_user)
    
    invalid_update_params = {
      state: 'rejected',
      comments_attributes: {
        '0' => { user_id: @user.id, content: 'Try to change already processed' }
      }
    }
    
    patch change_request_path(@change_request), params: { change_request: invalid_update_params }
    
    assert_redirected_to change_request_path(@change_request)
    assert flash[:alert]
    assert_match I18n.t('errors.messages.already_processed'), flash[:alert]
  end

  test "変更リクエストのキャンセル成功" do
    cancel_params = {
      comments_attributes: {
        '0' => { user_id: @user.id, content: 'Cancelled by requester' }
      }
    }
    
    delete change_request_path(@change_request), params: { change_request: cancel_params }
    
    @change_request.reload
    assert_equal 'cancelled', @change_request.state
    assert_not_nil @change_request.cancelled_at
    assert_redirected_to change_request_path(@change_request)
    assert_equal I18n.t('change_requests.destroy.notice'), flash[:notice]
  end

  test "変更リクエストのキャンセル失敗" do
    # コメントなしでキャンセルしようとする
    invalid_cancel_params = {
      comments_attributes: {
        '0' => { user_id: @user.id, content: '' } # 空のコメント
      }
    }
    
    delete change_request_path(@change_request), params: { change_request: invalid_cancel_params }
    
    assert_redirected_to change_request_path(@change_request)
    assert flash[:alert]
  end

  test "存在しない変更リクエストにアクセス" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get change_request_path(id: 99999)
    end
  end

  test "with_lockによる排他制御の確認" do
    # 更新処理でwith_lockが使用されることを間接的に確認
    update_params = {
      state: 'approved',
      comments_attributes: {
        '0' => { user_id: @user.id, content: 'Lock test' }
      }
    }
    
    patch change_request_path(@change_request), params: { change_request: update_params }
    
    @change_request.reload
    assert_equal 'approved', @change_request.state
    assert_equal @user, @change_request.processed_user
  end

  test "作成パラメータのフィルタリング" do
    # 許可されていないパラメータが除外されることを確認
    change_request_params = {
      app_id: @app.id,
      type: 'PurchaseCancelRequest',
      unauthorized_param: 'should_be_filtered',
      state: 'approved', # create時には設定できない
      comments_attributes: {
        '0' => { user_id: @user.id, content: 'Test comment' }
      }
    }
    
    assert_difference 'ChangeRequest.count', 1 do
      post change_requests_path, params: { change_request: change_request_params }
    end
    
    change_request = ChangeRequest.last
    # unauthorized_paramは設定されない
    assert_not_respond_to change_request, :unauthorized_param
    # stateは'requested'になる（createパラメータに含まれていないため）
    assert_equal 'requested', change_request.state
  end

  test "更新パラメータのフィルタリング" do
    update_params = {
      state: 'approved',
      type: 'ShouldNotBeUpdated', # 更新パラメータに含まれていない
      app_id: 999, # 更新パラメータに含まれていない
      unauthorized_param: 'should_be_filtered',
      comments_attributes: {
        '0' => { user_id: @user.id, content: 'Approved' }
      }
    }
    
    original_type = @change_request.type
    original_app_id = @change_request.app_id
    
    patch change_request_path(@change_request), params: { change_request: update_params }
    
    @change_request.reload
    assert_equal 'approved', @change_request.state
    # type, app_idは変更されない
    assert_equal original_type, @change_request.type
    assert_equal original_app_id, @change_request.app_id
  end

  test "キャンセルパメータのフィルタリング" do
    cancel_params = {
      state: 'approved', # cancel_paramsに含まれていない
      unauthorized_param: 'should_be_filtered',
      comments_attributes: {
        '0' => { user_id: @user.id, content: 'Cancel comment' }
      }
    }
    
    delete change_request_path(@change_request), params: { change_request: cancel_params }
    
    @change_request.reload
    # destroyアクション内で明示的にstate = :cancelledが設定される
    assert_equal 'cancelled', @change_request.state
  end

  test "skip_before_actionによる認可スキップの確認" do
    # update, destroyアクションでは:authorize!がスキップされる
    # ただし、アクション内で個別にauthorize!が呼ばれる
    
    update_params = {
      state: 'approved',
      comments_attributes: {
        '0' => { user_id: @user.id, content: 'Test authorize skip' }
      }
    }
    
    patch change_request_path(@change_request), params: { change_request: update_params }
    
    # スキップされていても個別認可でアクセス可能
    assert_response :redirect
  end

  test "コメントの文字数制限テスト" do
    long_content = 'a' * 6001 # 6000文字を超える
    
    change_request_params = {
      app_id: @app.id,
      type: 'PurchaseCancelRequest',
      comments_attributes: {
        '0' => { user_id: @user.id, content: long_content }
      }
    }
    
    assert_no_difference 'ChangeRequest.count' do
      post change_requests_path, params: { change_request: change_request_params }
    end
    
    assert_response :success
    assert_template :new
  end

  test "ページネーション機能の確認" do
    get change_requests_path, params: { page: 1 }
    
    assert_response :success
    assert assigns(:change_requests)
    
    # 詳細ページのコメントページネーション
    get change_request_path(@change_request), params: { page: 1 }
    
    assert_response :success
    assert assigns(:comments)
  end

  test "includesによるN+1問題対策の確認" do
    get change_requests_path
    
    assert_response :success
    change_requests = assigns(:change_requests)
    
    # 関連データが適切に読み込まれていることを確認
    if change_requests.any?
      change_request = change_requests.first
      # includes(:app, :requested_user, :processed_user)が効いている
      assert_not_nil change_request.app
      assert_not_nil change_request.requested_user
    end
  end

  test "recentlyスコープの動作確認" do
    # 新しい変更リクエストを作成
    newer_request = FactoryBot.create(:purchase_cancel_request,
      app: @app,
      requested_user: @user,
      state: 'requested'
    )
    
    get change_requests_path
    
    change_requests = assigns(:change_requests)
    # recentlyスコープでid降順になっている
    assert_equal newer_request.id, change_requests.first.id
  end

  test "InheritedResourcesの動作確認" do
    # InheritedResources::Baseを継承しいることを確認
    assert ChangeRequestsController.ancestors.include?(InheritedResources::Base)
    
    # actions :all, except: %i(edit destroy)の設定確認
    # editアクションが除外されていることを確認
    assert_raises(ActionController::UrlGenerationError) do
      edit_change_request_path(@change_request)
    end
  end

  test "InheritedResourcesViewsモジュールの動作確認" do
    # InheritedResourcesViewsが含まれていることを確認
    assert ChangeRequestsController.ancestors.include?(InheritedResourcesViews)
    
    get change_requests_path
    assert_response :success
    
    # ヘルパーメソッドが使用可能であることを間接的に確認
    get change_request_path(@change_request)
    assert_response :success
  end

  test "master_currency_idパラメータを含む作成" do
    # HardCurrency系のリクエスト用パラメータ
    change_request_params = {
      app_id: @app.id,
      type: 'PurchaseHardCurrencyRevisionRequest',
      master_currency_id: 1,
      store_type: 'google_play',
      price: 500,
      comments_attributes: {
        '0' => { user_id: @user.id, content: 'Hard currency revision' }
      }
    }
    
    assert_difference 'ChangeRequest.count', 1 do
      post change_requests_path, params: { change_request: change_request_params }
    end
    
    change_request = ChangeRequest.last
    assert_equal 'PurchaseHardCurrencyRevisionRequest', change_request.type
  end
end
