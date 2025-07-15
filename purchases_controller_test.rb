require "test_helper"

class PurchasesControllerTest < ActionDispatch::IntegrationTest
  include LoginHelper

  def setup
    signed_in_user(:user, { role: :administrator })
    @app = apps(:valid_app)
    @purchase = purchases(:valid_purchase)
    @app.purchases << @purchase
  end

  test "should get index" do
    get app_purchases_path(@app)
    assert_response :success
    assert_not_nil assigns(:search_form)
    assert_not_nil assigns(:purchases)
    assert_not_nil assigns(:purchase_cancel_request)
  end

  test "should get index with search params" do
    search_params = {
      app_id: @app.id,
      from: 1.week.ago.to_date,
      to: Date.current
    }
    
    get app_purchases_path(@app), params: { q: search_params }
    
    assert_response :success
    assert_equal search_params[:app_id], assigns(:search_form).app_id
    assert_equal search_params[:from], assigns(:search_form).from
    assert_equal search_params[:to], assigns(:search_form).to
  end

  test "should get index with pagination" do
    get app_purchases_path(@app), params: { page: 2 }
    assert_response :success
  end

  test "should build cancel request comment for current user" do
    user = users(:user)
    signed_in_user(user)
    
    get app_purchases_path(@app)
    
    cancel_request = assigns(:purchase_cancel_request)
    assert_not_nil cancel_request
    assert_equal @app.id, cancel_request.app_id
    assert cancel_request.comments.any?
    assert_equal user, cancel_request.comments.first.user
  end

  test "should show purchase" do
    get app_purchase_path(@app, @purchase)
    
    assert_response :success
    assert_equal @purchase, assigns(:purchase)
  end

  test "should handle non-existent purchase in show" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get app_purchase_path(@app, id: 999999)
    end
  end

  test "should handle non-existent app" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get app_purchases_path(id: 999999)
    end
  end

  test "should filter permitted search params" do
    # 許可されていないパラメータが除外されることをテスト
    get app_purchases_path(@app), params: { 
      q: { 
        app_id: @app.id, 
        from: 1.week.ago.to_date, 
        to: Date.current,
        unauthorized_param: 'should_be_filtered'
      } 
    }
    
    assert_response :success
    search_form = assigns(:search_form)
    # unauthorized_param が含まれていないことを確認
    assert_nil search_form.try(:unauthorized_param)
  end

  test "should handle empty search params" do
    get app_purchases_path(@app), params: { q: {} }
    assert_response :success
  end

  test "should handle missing search params" do
    get app_purchases_path(@app)
    assert_response :success
  end
end
