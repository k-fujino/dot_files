require 'test_helper'

class HardCurrencyAggregationsControllerTest < ActionDispatch::IntegrationTest
  include LoginHelper

  setup do
    signed_in_user(:user, { role: :administrator })
    @identifier = :foo
  end
  test "download stack aggregator csv" do
    target_date = Date.new(2017, 1, 31)
    hard_currency_aggregation_params = { identifier: @identifier, year: target_date.year, month: target_date.month }
    get hard_currency_aggregations_path, params: { q: hard_currency_aggregation_params, format: :csv }

    assert_response :success
    assert { response.header["Content-Type"] == "text/csv" }
  end
end
