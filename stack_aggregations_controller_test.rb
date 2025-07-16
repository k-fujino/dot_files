require 'test_helper'

class StackAggregationsControllerTest < ActionDispatch::IntegrationTest
  include LoginHelper

  setup do
    signed_in_user(:user, { role: :administrator })
    @identifier = :foo
  end

  test "パラメータなしでインデックスを取得" do
    get stack_aggregations_path
    assert_response :success
    assert_template :index
    assert assigns(:stack_aggregator)
    assert_not assigns(:stack_aggregator).aggregate
  end

  test "有効なパラメータでインデックスを取得" do
    target_date = Date.new(2017, 1, 31)
    stack_aggregation_params = { 
      identifier: @identifier, 
      year: target_date.year, 
      month: target_date.month, 
      including_tax: true 
    }
    
    get stack_aggregations_path, params: { q: stack_aggregation_params }
    
    assert_response :success
    assert_template :index
    assert assigns(:stack_aggregator)
    assert_equal @identifier, assigns(:stack_aggregator).identifier
    assert_equal target_date.year, assigns(:stack_aggregator).year
    assert_equal target_date.month, assigns(:stack_aggregator).month
    assert assigns(:stack_aggregator).including_tax
  end

  test "不正なパラメータを除外してインデックスを取得" do
    get stack_aggregations_path, params: { 
      q: { 
        identifier: @identifier, 
        year: 2017, 
        month: 1, 
        including_tax: true,
        invalid_param: 'should_be_filtered' # permitted_paramsで除外される
      } 
    }
    
    assert_response :success
    assert_template :index
    assert assigns(:stack_aggregator)
    # invalid_paramは設定されていないことを確認
    assert_not_respond_to assigns(:stack_aggregator), :invalid_param
  end

  test "HTML形式でCSVダウンロードリンクが表示される" do
    target_date = Date.new(2017, 1, 31)
    stack_aggregation_params = { 
      identifier: @identifier, 
      year: target_date.year, 
      month: target_date.month, 
      including_tax: true 
    }
    
    get stack_aggregations_path, params: { q: stack_aggregation_params }
    
    assert_response :success
    # CSVダウンロードリンクがページに含まれていることを確認
    assert_select 'a[href*="format=csv"]'
  end

  test "CSVダウンロード形式でスタックアグリゲーターを取得" do
    target_date = Date.new(2017, 1, 31)
    stack_aggregation_params = { 
      identifier: @identifier, 
      year: target_date.year, 
      month: target_date.month, 
      including_tax: true 
    }
    
    get stack_aggregations_path, params: { q: stack_aggregation_params, format: :csv }

    assert_response :success
    assert_equal "text/csv", response.header["Content-Type"]
    
    # ファイル名の形式をチェック
    expected_filename = "#{target_date.year}-#{target_date.month}-obelisk-#{@identifier}-tax-included.csv"
    assert response.header["Content-Disposition"].include?(expected_filename)
  end

  test "税抜きパラメータでCSVダウンロード" do
    target_date = Date.new(2017, 1, 31)
    stack_aggregation_params = { 
      identifier: @identifier, 
      year: target_date.year, 
      month: target_date.month, 
      including_tax: false 
    }
    
    get stack_aggregations_path, params: { q: stack_aggregation_params, format: :csv }

    assert_response :success
    assert_equal "text/csv", response.header["Content-Type"]
    
    # ファイル名に"excluded"が含まれることを確認
    expected_filename = "#{target_date.year}-#{target_date.month}-obelisk-#{@identifier}-tax-excluded.csv"
    assert response.header["Content-Disposition"].include?(expected_filename)
  end

  test "年のみ指定でインデックスを取得" do
    get stack_aggregations_path, params: { q: { year: 2017 } }
    
    assert_response :success
    assert_template :index
    assert assigns(:stack_aggregator)
    assert_equal 2017, assigns(:stack_aggregator).year
    assert_nil assigns(:stack_aggregator).month
    assert_nil assigns(:stack_aggregator).identifier
  end

  test "月のみ指定でインデックスを取得" do
    get stack_aggregations_path, params: { q: { month: 1 } }
    
    assert_response :success
    assert_template :index
    assert assigns(:stack_aggregator)
    assert_equal 1, assigns(:stack_aggregator).month
    assert_nil assigns(:stack_aggregator).year
    assert_nil assigns(:stack_aggregator).identifier
  end

  test "identifierのみ指定でインデックスを取得" do
    get stack_aggregations_path, params: { q: { identifier: @identifier } }
    
    assert_response :success
    assert_template :index
    assert assigns(:stack_aggregator)
    assert_equal @identifier, assigns(:stack_aggregator).identifier
    assert_nil assigns(:stack_aggregator).year
    assert_nil assigns(:stack_aggregator).month
  end

  test "including_taxのみ指定でインデックスを取得" do
    get stack_aggregations_path, params: { q: { including_tax: false } }
    
    assert_response :success
    assert_template :index
    assert assigns(:stack_aggregator)
    assert_not assigns(:stack_aggregator).including_tax
    assert_nil assigns(:stack_aggregator).year
    assert_nil assigns(:stack_aggregator).month
    assert_nil assigns(:stack_aggregator).identifier
  end

  test "resource_classヘルパーメソッドの動作確認" do
    get stack_aggregations_path
    
    assert_response :success
    # ヘルパーメソッドが正しく定義されていることを確認するため、
    # controllerインスタンスから直接アクセス
    assert_equal ::StackAggregator, @controller.send(:resource_class)
  end

  test "permitted_paramsメソッドの動作確認" do
    # 全てのpermitted_paramsを含むリクエスト
    all_params = {
      identifier: @identifier,
      year: 2017,
      month: 1,
      including_tax: true
    }
    
    get stack_aggregations_path, params: { q: all_params }
    
    assert_response :success
    
    # controller内でpermitted_paramsが正しく処理されることを確認
    stack_aggregator = assigns(:stack_aggregator)
    assert_equal @identifier, stack_aggregator.identifier
    assert_equal 2017, stack_aggregator.year
    assert_equal 1, stack_aggregator.month
    assert stack_aggregator.including_tax
  end

  test "basenameメソッドによるファイル名生成の確認" do
    target_date = Date.new(2017, 1, 31)
    stack_aggregation_params = { 
      identifier: @identifier, 
      year: target_date.year, 
      month: target_date.month, 
      including_tax: true 
    }
    
    get stack_aggregations_path, params: { q: stack_aggregation_params, format: :csv }
    
    assert_response :success
    
    # basenameの構成要素が正しく含まれていることを確認
    content_disposition = response.header["Content-Disposition"]
    assert content_disposition.include?("2017")
    assert content_disposition.include?("1") 
    assert content_disposition.include?("obelisk")
    assert content_disposition.include?(@identifier.to_s)
    assert content_disposition.include?("tax")
    assert content_disposition.include?("included")
  end

  test "filenameメソッドによるCSV拡張子の確認" do
    target_date = Date.new(2017, 1, 31)
    stack_aggregation_params = { 
      identifier: @identifier, 
      year: target_date.year, 
      month: target_date.month, 
      including_tax: true 
    }
    
    get stack_aggregations_path, params: { q: stack_aggregation_params, format: :csv }
    
    assert_response :success
    
    # ファイル名がCSV拡張子で終わることを確認
    content_disposition = response.header["Content-Disposition"]
    assert content_disposition.include?(".csv")
  end

  private

  # テスト用のスタブメソッド（実際のStackAggregatorの動作をシミュレート）
  def setup_stack_aggregator_stub
    # 必要に応じてStackAggregatorのスタブを設定
    # 現在のテストではActiveTypeオブジェクトの基本的な動作のみをテスト
  end
end
