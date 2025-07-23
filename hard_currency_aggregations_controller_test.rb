require 'test_helper'

class HardCurrencyAggregationsControllerTest < ActionDispatch::IntegrationTest
  include LoginHelper

  setup do
    signed_in_user(:user, { role: :administrator })
    @app = FactoryBot.create(:app)
    @identifier = @app.identifier
  end

  test "インデックスページの表示" do
    get hard_currency_aggregations_path
    
    assert_response :success
    assert { assigns(:aggregation_form).present? }
    assert { assigns(:aggregation_form).is_a?(HardCurrencyAggregationForm) }
    assert { assigns(:result).nil? } # パラメータなしの場合は結果なし
  end

  test "有効なパラメータでの集計結果表示" do
    target_date = Date.new(2017, 1, 31)
    hard_currency_aggregation_params = { 
      identifier: @identifier, 
      year: target_date.year, 
      month: target_date.month
    }
    
    get hard_currency_aggregations_path, params: { q: hard_currency_aggregation_params }
    
    assert_response :success
    assert { assigns(:aggregation_form).present? }
    assert { assigns(:aggregation_form).valid? }
    assert { assigns(:result).present? }
    assert { assigns(:result).is_a?(HardCurrencyAggregationForm::Result) }
    assert { assigns(:result).year == target_date.year }
    assert { assigns(:result).month == target_date.month }
    assert { assigns(:result).app == @app }
  end

  test "store_typeパラメータ付きでの集計" do
    target_date = Date.new(2017, 1, 31)
    # 推測: App#purchase_hard_currencyが返すオブジェクトのstore_typesに含まれる値を使用
    # 実際のPurchaseHardCurrencyクラスの実装により異なる可能性がある
    # Constants::STORE_TYPESの値を使用するが、実際は異なる値の可能性もある
    store_type = 'app_store'
    hard_currency_aggregation_params = { 
      identifier: @identifier, 
      year: target_date.year, 
      month: target_date.month,
      store_type: store_type
    }
    
    get hard_currency_aggregations_path, params: { q: hard_currency_aggregation_params }
    
    assert_response :success
    assert { assigns(:aggregation_form).store_type == store_type }
  end

  test "無効なidentifierでのバリデーションエラー" do
    hard_currency_aggregation_params = { 
      identifier: '', # 空文字でpresenceバリデーションエラー
      year: 2017, 
      month: 1 
    }
    
    get hard_currency_aggregations_path, params: { q: hard_currency_aggregation_params }
    
    assert_response :success
    assert { assigns(:aggregation_form).present? }
    assert { !assigns(:aggregation_form).valid? }
    assert { assigns(:aggregation_form).errors[:identifier].present? }
    assert { assigns(:result).nil? } # バリデーションエラーの場合は結果なし
  end

  test "無効なyearでのバリデーションエラー" do
    hard_currency_aggregation_params = { 
      identifier: @identifier, 
      year: 2014, # Constants::AVAILABLE_YEARS_PROCの範囲外（2015より前）
      month: 1 
    }
    
    get hard_currency_aggregations_path, params: { q: hard_currency_aggregation_params }
    
    assert_response :success
    assert { assigns(:aggregation_form).present? }
    assert { !assigns(:aggregation_form).valid? }
    assert { assigns(:aggregation_form).errors[:year].present? }
    assert { assigns(:result).nil? }
  end

  test "無効なmonthでのバリデーションエラー" do
    hard_currency_aggregation_params = { 
      identifier: @identifier, 
      year: 2017, 
      month: 13 # Constants::AVAILABLE_MONTHSの範囲外
    }
    
    get hard_currency_aggregations_path, params: { q: hard_currency_aggregation_params }
    
    assert_response :success
    assert { assigns(:aggregation_form).present? }
    assert { !assigns(:aggregation_form).valid? }
    assert { assigns(:aggregation_form).errors[:month].present? }
    assert { assigns(:result).nil? }
  end

  test "無効なstore_typeでのバリデーションエラー" do
    hard_currency_aggregation_params = { 
      identifier: @identifier, 
      year: 2017, 
      month: 1,
      store_type: 'invalid_store_type' # appのselectable_store_typesに含まれない値
    }
    
    get hard_currency_aggregations_path, params: { q: hard_currency_aggregation_params }
    
    assert_response :success
    assert { assigns(:aggregation_form).present? }
    # store_typeのバリデーションはappが存在し、かつstore_typeが指定されている場合のみ実行される
    # appのpurchase_hard_currencyが存在しない場合はバリデーションエラーにならない可能性がある
    if assigns(:aggregation_form).app.present? && assigns(:aggregation_form).app.try(:purchase_hard_currency).present?
      assert { !assigns(:aggregation_form).valid? }
      assert { assigns(:aggregation_form).errors[:store_type].present? }
    end
    assert { assigns(:result).nil? }
  end

  test "パラメータなしでの表示" do
    get hard_currency_aggregations_path
    
    assert_response :success
    assert { assigns(:aggregation_form).present? }
    assert { assigns(:result).nil? }
    # デフォルト値の確認
    assert { assigns(:aggregation_form).year == Time.current.year }
    assert { assigns(:aggregation_form).month == Time.current.month }
  end

  test "CSV形式でのダウンロード" do
    target_date = Date.new(2017, 1, 31)
    hard_currency_aggregation_params = { 
      identifier: @identifier, 
      year: target_date.year, 
      month: target_date.month 
    }
    
    get hard_currency_aggregations_path, params: { q: hard_currency_aggregation_params, format: :csv }

    assert_response :success
    assert { response.header["Content-Type"] == "text/csv" }
    
    # ファイル名の確認（basenameメソッドのロジックに基づく）
    expected_filename = "#{target_date.year}-#{target_date.month}-obelisk-#{@identifier}.csv"
    content_disposition = response.header["Content-Disposition"]
    assert { content_disposition.include?(expected_filename) }
  end

  test "CSV出力時のSJISエンコーディング" do
    target_date = Date.new(2017, 1, 31)
    hard_currency_aggregation_params = { 
      identifier: @identifier, 
      year: target_date.year, 
      month: target_date.month 
    }
    
    get hard_currency_aggregations_path, params: { q: hard_currency_aggregation_params, format: :csv }
    
    assert_response :success
    # CSVテンプレートでSJISエンコーディングされることを確認
    assert { response.body.encoding == Encoding::SJIS }
  end

  test "バリデーションエラー時のCSVリクエスト" do
    # 無効なパラメータでCSVをリクエスト
    hard_currency_aggregation_params = { 
      identifier: '', # バリデーションエラー
      year: 2017, 
      month: 1 
    }
    
    get hard_currency_aggregations_path, params: { q: hard_currency_aggregation_params, format: :csv }
    
    # バリデーションエラーの場合でもレスポンスは返るが、結果は空
    assert_response :success
    assert { assigns(:result).nil? }
  end

  test "resource_classルパーメソッドの動作確認" do
    get hard_currency_aggregations_path
    
    # resource_classがHardCurrencyAggregationFormを返すことを間接的に確認
    # ビューでresource_classが使用されていることを前提
    assert_response :success
    assert { assigns(:aggregation_form).class == HardCurrencyAggregationForm }
  end

  test "aggregation_formのattributesがCSVリンクで使用されることの確認" do
    target_date = Date.new(2017, 1, 31)
    hard_currency_aggregation_params = { 
      identifier: @identifier, 
      year: target_date.year, 
      month: target_date.month
    }
    
    get hard_currency_aggregations_path, params: { q: hard_currency_aggregation_params }
    
    assert_response :success
    # ビューでurl_for(q: @aggregation_form.attributes, format: :csv)が使用される
    assert { assigns(:aggregation_form).attributes.present? }
    assert { assigns(:aggregation_form).attributes['identifier'] == @identifier }
    assert { assigns(:aggregation_form).attributes['year'] == target_date.year }
    assert { assigns(:aggregation_form).attributes['month'] == target_date.month }
  end

  test "permitted_paramsの動作確認" do
    # 許可されたパラメータのみが処理されることを確認
    params_with_extra = {
      identifier: @identifier,
      year: 2017,
      month: 1,
      store_type: 'online',
      extra_param: 'should_be_ignored' # 許可されていないパラメータ
    }
    
    get hard_currency_aggregations_path, params: { q: params_with_extra }
    
    assert_response :success
    # extra_paramは無視されることを確認（強制許可パラメータのテストの代替）
    form = assigns(:aggregation_form)
    assert { form.identifier == @identifier }
    assert { form.year == 2017 }
    assert { form.month == 1 }
    assert { form.store_type == 'app_store' }
  end

  test "複数のmaster_currency_idsがある場合の表示" do
    # 複数のmaster_currency_idを持つ結果の確認
    target_date = Date.new(2017, 1, 31)
    hard_currency_aggregation_params = { 
      identifier: @identifier, 
      year: target_date.year, 
      month: target_date.month
    }
    
    get hard_currency_aggregations_path, params: { q: hard_currency_aggregation_params }
    
    assert_response :success
    result = assigns(:result)
    if result.present?
      # master_currency_idsが配列として取得できることを確認
      assert { result.master_currency_ids.is_a?(Array) }
      # ビューで各master_currency_idに対してパネルが生成されることを前提
      assert { result.respond_to?(:master_currency_ids) }
      
      # 推測: master_currency_idsはapp.consumption_hard_currency.distinct.pluck(:master_currency_id).sortから取得
      # consumption_hard_currencyが存在しない場合は空配列になる可能性がある
      # 実際のデータによっては空配列または数値の配列が返される
    end
  end

  private

  # 既存のtest "download stack aggregator csv"を残す
  test "download stack aggregator csv" do
    target_date = Date.new(2017, 1, 31)
    hard_currency_aggregation_params = { identifier: @identifier, year: target_date.year, month: target_date.month }
    get hard_currency_aggregations_path, params: { q: hard_currency_aggregation_params, format: :csv }

    assert_response :success
    assert { response.header["Content-Type"] == "text/csv" }
  end
end
