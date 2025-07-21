# == Schema Information
#
# Table name: change_requests
#
#  id                :integer          not null, primary key
#  app_id            :integer          not null
#  requested_user_id :integer          not null
#  processed_user_id :integer
#  type              :string(255)      not null
#  state             :string(255)      not null
#  properties        :text(4294967295)
#  requested_at      :datetime         not null
#  cancelled_at      :datetime
#  approved_at       :datetime
#  rejected_at       :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_change_requests_on_app_id             (app_id)
#  index_change_requests_on_processed_user_id  (processed_user_id)
#  index_change_requests_on_requested_user_id  (requested_user_id)
#  index_change_requests_on_state              (state)
#  index_change_requests_on_type               (type)
#

require "test_helper"

class ChangeRequestsControllerTest < ActionDispatch::IntegrationTest
  # def test_sanity
  #   flunk "Need real tests"
  # end
end
