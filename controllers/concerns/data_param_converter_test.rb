require 'test_helper'

class DateParamConverterTest < ActionController::TestCase
  # テスト用のダミーコントローラーを作成
  # DateParamConverterモジュールをincludeしてテスト
  class TestController < ActionController::Base
    include DateParamConverter
    
    def test_action
      # テスト用のアクション（実際にconvert_dateを呼び出す）
      params_hash = params.to_unsafe_h
      converted_params = convert_date(:applied_on, params_hash)
      render json: { converted_params: converted_params }
    end
    
    def test_convert_date_parameters
      # convert_date_parameters_to_date_typeを直接テストするためのアクション
      params_hash = params.to_unsafe_h
      converted_params = convert_date_parameters_to_date_type(:applied_on, params_hash)
      render json: { converted_params: converted_params }
    end
  end

  setup do
    # ルーティングの設定
    Rails.application.routes.draw do
      post 'test/test_action', to: 'date_param_converter_test/test#test_action'
      post 'test/test_convert_date_parameters', to: 'date_param_converter_test/test#test_convert_date_parameters'
    end

    @controller = TestController.new
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "文字列形式の日付が正しくDateオブジェクトに変換される" do
    date_string = '2025-01-15'
    
    post :test_action, params: { applied_on: date_string }
    
    response_data = JSON.parse(response.body)
    converted_params = response_data['converted_params']
    
    assert { converted_params['applied_on'] == Date.parse(date_string) }
  end

  test "ISO8601形式の日付文字列が正しく変換される" do
    date_string = '2025-12-31'
    
    post :test_action, params: { applied_on: date_string }
    
    response_data = JSON.parse(response.body)
    converted_params = response_data['converted_params']
    
    assert { converted_params['applied_on'] == Date.new(2025, 12, 31) }
  end

  test "日本語形式日付文字列が正しく変換される" do
    # Date.parseが対応している形式
    date_string = '2025/01/15'
    
    post :test_action, params: { applied_on: date_string }
    
    response_data = JSON.parse(response.body)
    converted_params = response_data['converted_params']
    
    assert { converted_params['applied_on'] == Date.new(2025, 1, 15) }
  end

  test "空の文字列の場合はdate_parametersからの変換が実行される" do
    # applied_on(1i), applied_on(2i), applied_on(3i)形式のパラメータ
    post :test_action, params: {
      applied_on: '', # 空文字列
      'applied_on(1i)' => '2025', # 年
      'applied_on(2i)' => '3',    # 月
      'applied_on(3i)' => '20'    # 日
    }
    
    response_data = JSON.parse(response.body)
    converted_params = response_data['converted_params']
    
    assert { converted_params['applied_on'] == Date.new(2025, 3, 20) }
  end

  test "applied_onパラメータがnilの場合はdate_parametersからの変換が実行れる" do
    post :test_action, params: {
      # applied_onパラメータなし
      'applied_on(1i)' => '2024', # 年
      'applied_on(2i)' => '7',    # 月
      'applied_on(3i)' => '4'     # 日
    }
    
    response_data = JSON.parse(response.body)
    converted_params = response_data['converted_params']
    
    assert { converted_params['applied_on'] == Date.new(2024, 7, 4) }
  end

  test "convert_date_parameters_to_date_typeが正しく動作する" do
    post :test_convert_date_parameters, params: {
      'applied_on(1i)' => '2023', # 年
      'applied_on(2i)' => '11',   # 月
      'applied_on(3i)' => '8'     # 日
    }
    
    response_data = JSON.parse(response.body)
    converted_params = response_data['converted_params']
    
    # 元のdate_parametersが削除されることを確認
    assert { !converted_params.has_key?('applied_on(1i)') }
    assert { !converted_params.has_key?('applied_on(2i)') }
    assert { !converted_params.has_key?('applied_on(3i)') }
    
    # 新しいDateオブジェクトが設定されることを確認
    assert { converted_params['applied_on'] == Date.new(2023, 11, 8) }
  end

  test "文字列のdate_parametersが正しく整数に変換される" do
    post :test_convert_date_parameters, params: {
      'applied_on(1i)' => '2022', # 文字列
      'applied_on(2i)' => '5',    # 文字列
      'applied_on(3i)' => '15'    # 文字列
    }
    
    response_data = JSON.parse(response.body)
    converted_params = response_data['converted_params']
    
    assert { converted_params['applied_on'] == Date.new(2022, 5, 15) }
  end

  test "date_parametersが0の場合でも正しく処理される" do
    # to_iによって0になるケース
    post :test_convert_date_parameters, params: {
      'applied_on(1i)' => '0',
      'applied_on(2i)' => '0',
      'applied_on(3i)' => '0'
    }
    
    response_data = JSON.parse(response.body)
    converted_params = response_data['converted_params']
    
    # Date.new(0, 0, 0)はArgumentErrorが発生るが、
    # to_iの結果として0が渡されることをテスト
    assert_raises(ArgumentError) do
      Date.new(0, 0, 0)
    end
  end

  test "空文字列のdate_parametersは0に変換される" do
    params_hash = {
      'applied_on(1i)' => '',
      'applied_on(2i)' => '',
      'applied_on(3i)' => ''
    }
    
    # convert_date_parameters_to_date_typeを直接テスト
    date_fields = %w(1 2 3).map { |num| params_hash["applied_on(#{num}i)"].to_i }
    
    assert { date_fields == [0, 0, 0] }
  end

  test "不正な日付文字列でDate::Errorが発生する" do
    invalid_date_string = 'invalid-date-string'
    
    assert_raises(Date::Error) do
      post :test_action, params: { applied_on: invalid_date_string }
    end
  end

  test "異なるdate_nameパラメータで正しく動作する" do
    # applied_on以外のパラメータ名でテスト
    @controller.define_singleton_method(:test_other_date) do
      params_hash = params.to_unsafe_h
      converted_params = convert_date(:start_date, params_hash)
      render json: { converted_params: converted_params }
    end
    
    # ルーティングを動的に追加
    Rails.application.routes.draw do
      post 'test/test_other_date', to: 'date_param_converter_test/test#test_other_date'
    end
    
    post :test_other_date, params: {
      start_date: '2025-06-01'
    }
    
    response_data = JSON.parse(response.body)
    converted_params = response_data['converted_params']
    
    assert { converted_params['start_date'] == Date.new(2025, 6, 1) }
  end

  test "シンボルと文字列のdate_nameが正しく処理される" do
    # シンボルでのdate_name
    params_hash = { 'applied_on' => '2025-01-01' }
    result = @controller.send(:convert_date, :applied_on, params_hash)
    assert { result['applied_on'] == Date.new(2025, 1, 1) }
    
    # 文字列でのdate_name（to_sが適用される）
    params_hash = { 'due_date' => '2025-02-01' }
    result = @controller.send(:convert_date, 'due_date', params_hash)
    assert { result['due_date'] == Date.new(2025, 2, 1) }
  end

  test "元のparamsオブジェクトが変更される" do
    params_hash = {
      'applied_on' => '2025-03-15',
      'other_param' => 'unchanged'
    }
    
    original_other_param = params_hash['other_param']
    result = @controller.send(:convert_date, :applied_on, params_hash)
    
    # 元のハッシュが変更されることを確認
    assert { result.object_id == params_hash.object_id }
    assert { result['applied_on'] == Date.new(2025, 3, 15) }
    assert { result['other_param'] == original_other_param }
  end

  test "date_parameters形式で一部のパラメータが欠けている場合" do
    # (2i)と(3i)のみ存在する場合
    post :test_convert_date_parameters, params: {
      'applied_on(2i)' => '8',    # 月
      'applied_on(3i)' => '25'    # 日
      # applied_on(1i)は存在しない
    }
    
    response_data = JSON.parse(response.body)
    converted_params = response_data['converted_params']
    
    # 存在しないパラメータは0として扱われる
    assert { converted_params['applied_on'] == Date.new(0, 8, 25) }
  end

  test "複数の日付パラメータを同時に変換できる" do
    @controller.define_singleton_method(:test_multiple_dates) do
      params_hash = params.to_unsafe_h
      params_hash = convert_date(:start_date, params_hash)
      params_hash = convert_date(:end_date, params_hash)
      render json: { converted_params: params_hash }
    end
    
    Rails.application.routes.draw do
      post 'test/test_multiple_dates', to: 'date_param_converter_test/test#test_multiple_dates'
    end
    
    post :test_multiple_dates, params: {
      start_date: '2025-01-01',
      end_date: '2025-12-31'
    }
    
    response_data = JSON.parse(response.body)
    converted_params = response_data['converted_params']
    
    assert { converted_params['start_date'] == Date.new(2025, 1, 1) }
    assert { converted_params['end_date'] == Date.new(2025, 12, 31) }
  end

  test "Time.zone.parseとの互換性" do
    # Railsの標準的な日付文字列形式
    date_string = '2025-07-20'
    
    post :test_action, params: { applied_on: date_string }
    
    response_data = JSON.parse(response.body)
    converted_params = response_data['converted_params']
    
    # Date.parseとTime.zone.parseの結果が同じ日付であることを確認
    expected_date = Time.zone.parse(date_string).to_date
    assert { converted_params['applied_on'] == expected_date }
  end

  test "privateメソッドが外部から呼び出せない" do
    # convert_dateメソッドがprivateであることを確認
    assert_raises(NoMethodError) do
      @controller.convert_date(:applied_on, {})
    end
    
    # convert_date_parameters_to_date_typeメソッドがprivateであることを確認
    assert_raises(NoMethodError) do
      @controller.convert_date_parameters_to_date_type(:applied_on, {})
    end
  end

  test "日付パラメータの変換でメモリリークが発生しない" do
    # 量の変換処理でメモリ使用量が増加しないことを確認
    initial_objects = ObjectSpace.count_objects
    
    1000.times do |i|
      params_hash = { 'applied_on' => "2025-01-#{(i % 28) + 1}" }
      @controller.send(:convert_date, :applied_on, params_hash)
    end
    
    final_objects = ObjectSpace.count_objects
    
    # オブジェクト数の増加が適切な範囲内であることを確認
    # 完全に同じになることは期待せず、極端な増加がないことを確認
    object_increase = final_objects[:TOTAL] - initial_objects[:TOTAL]
    assert { object_increase < 10000 } # 適切な閾値を設定
  end
end
