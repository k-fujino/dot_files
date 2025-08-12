module StackAggregators
  class DailyConsumptionRevisionPrice < Base
    def aggregate
      # 毎回新しいハッシュインスタンスを生成するように修正
      ActiveSupport::HashWithIndifferentAccess.new do |h, k| 
        h[k] = ActiveSupport::HashWithIndifferentAccess.new { |h2, k2| h2[k2] = 0 }
      end.tap do |result|
        period.each do |date|
          consumption_revision_price_on_before(date).each do |store_type, price|
            result[store_type][date] = calculate_price(price)
          end
        end

        result[:total] = calculate_daily_total_price_from(result)
      end
    end

    private

    def consumption_revision_price_on_before(date)
      ConsumptionRevision(identifier).
        applied_on_before(date).
        group(:store_type).
        sum(:price)
    end
  end
end
