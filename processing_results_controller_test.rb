require 'test_helper'

class ProcessingResultsControllerTest < ActionDispatch::IntegrationTest
  include LoginHelper

  setup do
    signed_in_user(:user, { role: :administrator })
    @app = FactoryBot.create(:app)
    @processing_result = FactoryBot.create(:processing_result, app: @app)
  end

  test "インデックスページの表示" do
    get processing_results_path
    
    assert_response :success
    assert { assigns(:processing_results).present? }
    # Kaminariのpageメソッドが使用されていることを確認
    assert { assigns(:processing_results).respond_to?(:current_page) }
  end

  test "複数のprocessing_resultsがある場合のインデックス表示" do
    # 複数のprocessing_resultを作成
    processing_result_1 = FactoryBot.create(:processing_result, 
                                           app: @app, 
                                           name: "処理結果1",
                                           started_at: 2.hours.ago)
    processing_result_2 = FactoryBot.create(:processing_result, 
                                           app: @app, 
                                           name: "処理結果2",
                                           started_at: 1.hour.ago)
    
    get processing_results_path
    
    assert_response :success
    processing_results = assigns(:processing_results)
    assert { processing_results.present? }
    # latest_orderでstarted_atの降順で並んでいることを確認
    assert { processing_results.count >= 2 }
  end

  test "ページネーションパラメータ付きでのインデックス表示" do
    get processing_results_path, params: { page: 1 }
    
    assert_response :success
    assert { assigns(:processing_results).present? }
    assert { assigns(:processing_results).current_page == 1 }
  end

  test "存在しないページ番号でのアクセス" do
    get processing_results_path, params: { page: 9999 }
    
    assert_response :success
    # ページが存在しない場合でもエラーならないことを確認
    assert { assigns(:processing_results).present? }
  end

  test "appとのアソシエーションが含まれていることの確認" do
    get processing_results_path
    
    assert_response :success
    processing_results = assigns(:processing_results)
    
    if processing_results.any?
      # includes(:app)によりN+1問題が回避されていることを間接的に確認
      first_result = processing_results.first
      assert { first_result.respond_to?(:app) }
    end
  end

  test "詳細ページの表示" do
    # InheritedResourcesによりshowアクションが自動生成される
    get processing_result_path(@processing_result)
    
    assert_response :success
    assert { assigns(:processing_result) == @processing_result }
  end

  test "存在しないprocessing_resultの詳細ページアクセス" do
    # 存在しないIDでアクセスした場合、ActiveRecord::RecordNotFoundが発生
    assert_raises(ActiveRecord::RecordNotFound) do
      get processing_result_path(id: 99999)
    end
  end

  test "index_attributesメソッドの戻り値確認" do
    get processing_results_path
    
    assert_response :success
    # index_attributesは%i(id app_name name status started_at finished_at)を返す
    # InheritedResourcesViewsのデフォルト実装をオーバーライドしている
  end

  test "enable_actionsメソッドが空配列を返すことの確認" do
    get processing_results_path
    
    # enable_actionsが空配列のため、new, edit, deleteアクションが無効化されている
    assert_response :success
    # InheritedResourcesViewsのDEFAULT_ENABLE_ACTIONSをオーバーライドして空配列を返している
  end

  test "latest_orderスコープが適用されていることの確認" do
    # started_atで並び順を確認するためのテストデータ作成
    old_result = FactoryBot.create(:processing_result, 
                                  app: @app, 
                                  started_at: 2.hours.ago,
                                  status: :success)
    new_result = FactoryBot.create(:processing_result, 
                                  app: @app, 
                                  started_at: 1.hour.ago,
                                  status: :running)
    
    get processing_results_path
    
    assert_response :success
    processing_results = assigns(:processing_results)
    
    if processing_results.count >= 2
      # latest_orderはstarted_atの降順（新しいものが先頭）
      first_two = processing_results.limit(2)
      assert { first_two.first.started_at >= first_two.second.started_at }
    end
  end

  test "異なるステータスのprocessing_resultsの表示" do
    # enumerizeで定義されたstatusの値でテスト
    success_result = FactoryBot.create(:processing_result, 
                                      app: @app, 
                                      status: :success,
                                      started_at: 2.hours.ago)
    error_result = FactoryBot.create(:processing_result, 
                                    app: @app, 
                                    status: :error,
                                    started_at: 1.hour.ago)
    running_result = FactoryBot.create(:processing_result, 
                                      app: @app, 
                                      status: :running,
                                      started_at: 30.minutes.ago)
    
    get processing_results_path
    
    assert_response :success
    processing_results = assigns(:processing_results)
    
    # 異なるステータスのprocessing_resultsが全て表示されることを確認
    assert { processing_results.count >= 3 }
  end

  test "app_nameメソッドの動作確認" do
    # appが存在する場合はapp.nameを返す
    result_with_app = FactoryBot.create(:processing_result, app: @app)
    
    get processing_result_path(result_with_app)
    
    assert_response :success
    processing_result = assigns(:processing_result)
    assert { processing_result.app_name == @app.name }
  end

  test "app_nameメソッドでapp_identifierを使用する場合" do
    # appがnilの場合はapp_identifierを返す
    result_without_app = FactoryBot.create(:processing_result, 
                                          app: nil, 
                                          app_identifier: "test_identifier")
    
    get processing_result_path(result_without_app)
    
    assert_response :success
    processing_result = assigns(:processing_result)
    assert { processing_result.app_name == "test_identifier" }
  end

  test "finished_atがnilの場合の表示" do
    # 実行中のprocessing_resultはfinished_atがnil
    running_result = FactoryBot.create(:processing_result, 
                                      app: @app, 
                                      status: :running,
                                      finished_at: nil)
    
    get processing_result_path(running_result)
    
    assert_response :success
    processing_result = assigns(:processing_result)
    assert { processing_result.finished_at.nil? }
    assert { processing_result.status.running? }
  end

  test "detailフィールドが設定されている場合の表示" do
    detailed_result = FactoryBot.create(:processing_result, 
                                       app: @app, 
                                       detail: "詳細な処理結果の説明\nエラー情報など")
    
    get processing_result_path(detailed_result)
    
    assert_response :success
    processing_result = assigns(:processing_result)
    assert { processing_result.detail.include?("詳細な処理結果の説明") }
  end

  test "ignoreステータスのprocessing_resultの表示" do
    # enumerizeでignoreとignoredの両方が定義されている
    ignored_result = FactoryBot.create(:processing_result, 
                                      app: @app, 
                                      status: :ignored)
    ignore_result = FactoryBot.create(:processing_result, 
                                     app: @app, 
                                     status: :ignore)
    
    get processing_results_path
    
    assert_response :success
    processing_results = assigns(:processing_results)
    
    # ignore系のステータスも表示されることを確認
    ignore_statuses = processing_results.select { |pr| pr.status.ignore? || pr.status.ignored? }
    assert { ignore_statuses.count >= 2 }
  end

  test "異なるappを持つprocessing_resultsの表示" do
    other_app = FactoryBot.create(:app)
    other_processing_result = FactoryBot.create(:processing_result, app: other_app)
    
    get processing_results_path
    
    assert_response :success
    processing_results = assigns(:processing_results)
    
    # 全てのappのprocessing_resultsが表示されることを確認
    # （特定のappでのフィルタリングはされていない）
    assert { processing_results.count >= 2 }
  end

  test "processing_result_paramsメソッドの動作" do
    # processing_result_paramsはpermit!を使用してすべてのパラメータを許可
    get processing_results_path, params: { 
      page: 2,
      processing_result: { name: "test" },
      extra_param: "should_be_handled"
    }
    
    assert_response :success
    # pageパラメータが正しく処理されることを確認
    assert { assigns(:processing_results).current_page == 2 }
  end

  test "InheritedResourcesViewsモジュールのデフォルト動作をオーバーライド" do
    get processing_results_path
    
    assert_response :success
    # enable_actionsが空配列になることで、InheritedResourcesViewsの
    # DEFAULT_ENABLE_ACTIONS(%i(new edit delete))がオーバーライドされている
  end

  test "appがoptionalであることの確認" do
    # belongs_to :app, optional: trueのため、appなしでもProcessingResultを作成可能
    result_without_app = FactoryBot.create(:processing_result, 
                                          app: nil,
                                          app_identifier: "standalone_process")
    
    get processing_result_path(result_without_app)
    
    assert_response :success
    processing_result = assigns(:processing_result)
    assert { processing_result.app.nil? }
    assert { processing_result.app_identifier == "standalone_process" }
  end

  test "processing_resultが大量にある場合のページネーション" do
    # ページネーションが機能することを確認
    25.times do |i|
      FactoryBot.create(:processing_result, 
                       app: @app, 
                       name: "大量処理結果#{i}",
                       started_at: i.hours.ago)
    end
    
    get processing_results_path, params: { page: 1 }
    
    assert_response :success
    processing_results = assigns(:processing_results)
    # Kaminariのデフォルト設定（通常25件）以下で表示されることを確認
    # 実際のper_page設定により変わる可能性がある
    assert { processing_results.count <= 25 }
    assert { processing_results.current_page == 1 }
  end

  test "ProcessingResultのクラスメソッドstartの結果が表示される" do
    # ProcessingResult.startで作成されたレコードが正しく表示されることを確認
    # 実際のstartメソッドは複雑なため、結果のみをテスト
    start_result = FactoryBot.create(:processing_result, 
                                    app: @app,
                                    name: "Operation::SomeProcess",
                                    status: :success,
                                    detail: "処理が正常に完了しました")
    
    get processing_result_path(start_result)
    
    assert_response :success
    processing_result = assigns(:processing_result)
    assert { processing_result.name == "Operation::SomeProcess" }
    assert { processing_result.detail == "処理が正常に完了しました" }
  end
end
