module StackAggregators
  class DailyConsumptionRevisionPrice < Base
    def aggregate
      ActiveSupport::HashWithIndifferentAccess.new.tap do |result|
        # 各store_typeに対して明示的にハッシュを初期化
        store_types.each do |store_type|
          result[store_type] = {}
        end
        
        period.each do |date|
          # その日までの累積ではなく、その日の値だけを取得する必要がある
          consumption_revision_price_on(date).each do |store_type, price|
            result[store_type][date] = calculate_price(price)
          end
        end

        result[:total] = calculate_daily_total_price_from(result)
      end
    end

    private

    def consumption_revision_price_on(date)
      # applied_on_beforeではなく、その日のみのデータを取得
      ConsumptionRevision(identifier).
        where(applied_on: date).
        group(:store_type).
        sum(:price)
    end
  end
end
