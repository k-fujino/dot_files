# == Schema Information
#
# Table name: purchases
#
#  id                :integer          not null, primary key
#  identifier        :string(255)      not null
#  player_identifier :string(255)      not null
#  app_name          :string(255)
#  store_type        :string(255)      not null
#  points            :integer          not null
#  unit              :integer          default(1), not null
#  price             :integer          not null
#  purchased_at      :datetime         not null
#  parameters        :text(65535)
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  change_id         :integer
#  purchased_on      :date
#
# Indexes
#
#  index_purchases_on_identifier                          (identifier) UNIQUE
#  index_purchases_on_player_identifier_and_purchased_at  (player_identifier,purchased_at)
#

require "test_helper"

class PurchasesControllerTest < ActionDispatch::IntegrationTest
  # def test_sanity
  #   flunk "Need real tests"
  # end
end
