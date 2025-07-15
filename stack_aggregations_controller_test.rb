require 'test_helper'

class StackAggregationsControllerTest < ActionDispatch::IntegrationTest
  include LoginHelper

  setup do
    signed_in_user(:user, { role: :administrator })
    @identifier = :foo
    @target_date = Date.new(2017, 1, 31)
    @stack_aggregation_params = { 
      identifier: @identifier, 
      year: @target_date.year, 
      month: @target_date.month, 
      including_tax: true 
    }
  end

  test "should get index without params" do
    get stack_aggregations_path
    assert_response :success
    assert_not_nil assigns(:stack_aggregator)
  end

  test "should get index with valid params" do
    # StackAggregatorが正常にaggregateできることを前提とする
    StackAggregator.any_instance.stubs(:aggregate).returns(true)
    
    get stack_aggregations_path, params: { q: @stack_aggregation_params }
    
    assert_response :success
    assert_not_nil assigns(:stack_aggregator)
    assert_equal @identifier.to_s, assigns(:stack_aggregator).identifier
    assert_equal @target_date.year, assigns(:stack_aggregator).year
    assert_equal @target_date.month, assigns(:stack_aggregator).month
    assert_equal true, assigns(:stack_aggregator).including_tax
  end

  test "should handle aggregation failure" do
    # StackAggregatorがaggregateに失敗した場合
    StackAggregator.any_instance.stubs(:aggregate).returns(false)
    
    get stack_aggregations_path, params: { q: @stack_aggregation_params }
    
    assert_response :success
    # aggregateがfalseの場合の動作をテスト
  end

  test "download stack aggregator csv" do
    StackAggregator.any_instance.stubs(:aggregate).returns(true)
    
    get stack_aggregations_path, params: { q: @stack_aggregation_params, format: :csv }

    assert_response :success
    assert_equal "text/csv", response.header["Content-Type"]
    
    # Content-Dispositionヘッダーでファイル名が設定されているかテスト
    expected_filename = "2017-1-obelisk-foo-tax-included.csv"
    assert_match expected_filename, response.header["Content-Disposition"]
  end

  test "should generate correct filename for tax included" do
    StackAggregator.any_instance.stubs(:aggregate).returns(true)
    StackAggregator.any_instance.stubs(:year).returns(2017)
    StackAggregator.any_instance.stubs(:month).returns(1)
    StackAggregator.any_instance.stubs(:identifier).returns('foo')
    StackAggregator.any_instance.stubs(:including_tax).returns(true)
    
    get stack_aggregations_path, params: { q: @stack_aggregation_params, format: :csv }
    
    expected_filename = "2017-1-obelisk-foo-tax-included.csv"
    assert_match expected_filename, response.header["Content-Disposition"]
  end

  test "should generate correct filename for tax excluded" do
    params_without_tax = @stack_aggregation_params.merge(including_tax: false)
    
    StackAggregator.any_instance.stubs(:aggregate).returns(true)
    StackAggregator.any_instance.stubs(:year).returns(2017)
    StackAggregator.any_instance.stubs(:month).returns(1)
    StackAggregator.any_instance.stubs(:identifier).returns('foo')
    StackAggregator.any_instance.stubs(:including_tax).returns(false)
    
    get stack_aggregations_path, params: { q: params_without_tax, format: :csv }
    
    expected_filename = "2017-1-obelisk-foo-tax-excluded.csv"
    assert_match expected_filename, response.header["Content-Disposition"]
  end

  test "should respond to html format" do
    StackAggregator.any_instance.stubs(:aggregate).returns(true)
    
    get stack_aggregations_path, params: { q: @stack_aggregation_params, format: :html }
    
    assert_response :success
  end

  test "should filter permitted params" do
    params_with_extra = @stack_aggregation_params.merge(
      unauthorized_param: 'should_be_filtered',
      another_bad_param: 'also_filtered'
    )
    
    get stack_aggregations_path, params: { q: params_with_extra }
    
    assert_response :success
    # 許可されたパラメータのみが使用されることを確認
    aggregator = assigns(:stack_aggregator)
    assert_equal @identifier.to_s, aggregator.identifier
    assert_equal @target_date.year, aggregator.year
    assert_equal @target_date.month, aggregator.month
    assert_equal true, aggregator.including_tax
  end

  test "should handle empty params" do
    get stack_aggregations_path, params: { q: {} }
    assert_response :success
  end

  test "should handle missing params" do
    get stack_aggregations_path
    assert_response :success
  end

  test "resource_class should return StackAggregator" do
    controller = StackAggregationsController.new
    assert_equal ::StackAggregator, controller.send(:resource_class)
  end

  private

  # StackAggregatorのスタブ化のためのヘルパー
  def stub_stack_aggregator_success
    StackAggregator.any_instance.stubs(:aggregate).returns(true)
    StackAggregator.any_instance.stubs(:year).returns(@target_date.year)
    StackAggregator.any_instance.stubs(:month).returns(@target_date.month)
    StackAggregator.any_instance.stubs(:identifier).returns(@identifier.to_s)
    StackAggregator.any_instance.stubs(:including_tax).returns(true)
  end
end
