require 'test_helper'

class StackAggregationsControllerTest < ActionDispatch::IntegrationTest
  include LoginHelper

  setup do
    signed_in_user(:user, { role: :administrator })
    @identifier = :foo
  end
  test "download stack aggregator csv" do
    target_date = Date.new(2017, 1, 31)
    stack_aggregation_params = { identifier: @identifier, year: target_date.year, month: target_date.month, including_tax: true }
    get stack_aggregations_path, params: { q: stack_aggregation_params, format: :csv }

    assert_response :success
    assert { response.header["Content-Type"] == "text/csv" }
  end
end
