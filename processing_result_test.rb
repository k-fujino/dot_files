# == Schema Information
#
# Table name: processing_results
#
#  id             :integer          not null, primary key
#  app_id         :integer
#  name           :string(255)      not null
#  status         :string(255)      not null
#  started_at     :datetime         not null
#  finished_at    :datetime
#  detail         :text(65535)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  app_identifier :string(255)
#

require 'test_helper'

class ProcessingResultTest < ActiveSupport::TestCase
  setup do
    @app = FactoryBot.create(:app)
    @processing_result = FactoryBot.create(:processing_result, app: @app)
  end

  test 'has a valid factory' do
    assert FactoryBot.build(:processing_result).valid?
  end

  test 'delegate method' do
    assert { @processing_result.app.name == @processing_result.app_name }
  end

  test 'append detail from exception' do
    @message = 'error message'
    exception = StandardError.new(@message)
    
    # mockを使わずに実際のexceptionオブジェクトを使用
    @processing_result.append_detail_from(exception)
    assert { @processing_result.detail.include?(@message) }
  end

  test 'start' do
    identifier = @app.identifier

    name = 'processing for succeed'
    ProcessingResult.start(identifier, name) {}
    result = ProcessingResult.find_by(name: name)
    assert result.status.success?
    assert result.started_at.present?
    assert result.finished_at.present?

    name    = 'processing for ignored'
    message = 'exception message for ignored'
    assert_raises do
      ProcessingResult.start(identifier, name) do
        raise ProcessingJob::AlreadyProcessingError, message
      end
    end
    result = ProcessingResult.find_by(name: name)
    assert result.status.ignored?
    assert result.started_at.present?
    assert result.finished_at.present?
    assert { result.detail.include?(message) }

    name    = 'processing for error'
    message = 'exception message for error'
    assert_raises do
      ProcessingResult.start(identifier, name) { raise message }
    end
    result = ProcessingResult.find_by(name: name)
    assert result.status.error?
    assert result.started_at.present?
    assert result.finished_at.present?
    assert { result.detail.include?(message) }
  end

  test 'select_imported_files' do
    imported_date = Time.current.to_date
    files = %w(fizz buzz fizzbuzz)
    # :successトレイトの代わりに直接statusを指定
    FactoryBot.create(:processing_result, 
                     status: :success, 
                     detail: "buzz",
                     finished_at: imported_date.end_of_day)
    selected_files = ProcessingResult.select_imported_files(imported_date, files)
    assert { %w(buzz) == selected_files }
  end
end
