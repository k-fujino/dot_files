require 'test_helper'

class ChangeRequests::CommentsControllerTest < ActionController::TestCase
  setup do
    # FactoryBotを使用してテスト用ユーザーを作成
    @user = FactoryBot.create(:user, :administrator)
    
    # アプリとChangeRequestを作成
    @app = FactoryBot.create(:app, :with_manager)
    @change_request = FactoryBot.create(:change_request, 
      app: @app,
      requested_user: @user
    )
    
    # ログイン状態にする
    session[:user_id] = @user.id
  end

  test "有効なコメントが作成される" do
    comment_content = 'これは有効なコメントです'
    
    assert_difference '@change_request.comments.count', 1 do
      post :create, params: {
        change_request_id: @change_request.id,
        comment: {
          content: comment_content
        }
      }
    end
    
    assert_redirected_to change_request_url(@change_request)
    assert { flash[:notice] == 'コメントを作成しました' }
    
    # 作成されたコメントの確認
    created_comment = @change_request.comments.last
    assert { created_comment.content == comment_content }
    assert { created_comment.user == @user }
    assert { created_comment.commentable == @change_request }
  end

  test "空のコンテンツでコメント作成が失敗する" do
    assert_no_difference '@change_request.comments.count' do
      post :create, params: {
        change_request_id: @change_request.id,
        comment: {
          content: '' # presence: trueで無効
        }
      }
    end
    
    assert_redirected_to change_request_url(@change_request)
    # Comment#errorsではなく、change_request.errorsが参照されるため
    # アラートメッセージが表示される
    assert { flash[:alert].present? }
  end

  test "文字数上限を超えるコメントでエラーが発生する" do
    long_content = 'a' * 6001 # 6000文字の上限を超える
    
    assert_no_difference '@change_request.comments.count' do
      post :create, params: {
        change_request_id: @change_request.id,
        comment: {
          content: long_content
        }
      }
    end
    
    assert_redirected_to change_request_url(@change_request)
    assert { flash[:alert].present? }
  end

  test "最大文字数以内のコメントは正常に作成される" do
    valid_content = 'a' * 6000 # 6000文字ちょうど（上限内）
    
    assert_difference '@change_request.comments.count', 1 do
      post :create, params: {
        change_request_id: @change_request.id,
        comment: {
          content: valid_content
        }
      }
    end
    
    created_comment = @change_request.comments.last
    assert { created_comment.content == valid_content }
  end

  test "存在しないchange_requestでActiveRecord::RecordNotFoundが発生する" do
    assert_raises(ActiveRecord::RecordNotFound) do
      post :create, params: {
        change_request_id: 99999, # 存在しないID
        comment: {
          content: 'Test comment'
        }
      }
    end
  end

  test "current_userがコメントのuserに設定される" do
    other_user = FactoryBot.create(:user, :administrator)
    
    post :create, params: {
      change_request_id: @change_request.id,
      comment: {
        content: 'Test comment',
        user_id: other_user.id # 別のuser_idを指定してみる
      }
    }
    
    # user_idパラメータは無視され、current_userが設定されることを確認
    created_comment = @change_request.comments.last
    assert { created_comment.user == @user }
    assert { created_comment.user != other_user }
  end

  test "permitted_paramsがcontentのみを許可する" do
    params_hash = ActionController::Parameters.new({
      comment: {
        content: 'Valid content',
        user_id: 999, # 許可されていない
        created_at: Time.current, # 許可されていない
        commentable_id: 999, # 許可されていない
        commentable_type: 'FakeModel' # 許可されていない
      }
    })
    
    @controller.params = params_hash
    permitted_params = @controller.send(:permitted_params)
    
    # contentのみが許可されることを確認
    assert { permitted_params.has_key?('content') }
    assert { !permitted_params.has_key?('user_id') }
    assert { !permitted_params.has_key?('created_at') }
    assert { !permitted_params.has_key?('commentable_id') }
    assert { !permitted_params.has_key?('commentable_type') }
  end

  test "コメント作成成功時に正しいnoticeメッセージが表示される" do
    post :create, params: {
      change_request_id: @change_request.id,
      comment: {
        content: 'Test comment'
      }
    }
    
    assert_redirected_to change_request_url(@change_request)
    
    # change_requests.ja.ymlで定義されたメッセージが使用される
    assert { flash[:notice] == 'コメントを作成しました' }
  end

  test "コメント作成時にchange_requestとの関連が正しく設定される" do
    post :create, params: {
      change_request_id: @change_request.id,
      comment: {
        content: 'Test comment'
      }
    }
    
    created_comment = @change_request.comments.last
    assert { created_comment.commentable == @change_request }
    assert { created_comment.commentable_type == 'ChangeRequest' }
    assert { created_comment.commentable_id == @change_request.id }
  end

  test "未認証ユーザーはコメント作成できない" do
    session[:user_id] = nil # ログアウト状態
    
    post :create, params: {
      change_request_id: @change_request.id,
      comment: {
        content: 'Test comment'
      }
    }
    
    # ApplicationControllerのauthenticateによりリダイレクトされる
    assert_redirected_to signin_url
  end

  test "バンクされたユーザーはコメント作成できない" do
    banned_user = FactoryBot.create(:user, :banned)
    session[:user_id] = banned_user.id
    
    post :create, params: {
      change_request_id: @change_request.id,
      comment: {
        content: 'Test comment'
      }
    }
    
    # バンクされたユーザーは認証されないためリダイレクト
    assert_redirected_to signin_url
  end

  test "watcherユーザーもコメント作成できる" do
    watcher_user = FactoryBot.create(:user, :watcher)
    session[:user_id] = watcher_user.id
    
    assert_difference '@change_request.comments.count', 1 do
      post :create, params: {
        change_request_id: @change_request.id,
        comment: {
          content: 'Watcher comment'
        }
      }
    end
    
    created_comment = @change_request.comments.last
    assert { created_comment.user == watcher_user }
  end

  test "様々なChangeRequestタイプでコメント作成できる" do
    # ConsumptionRevisionRequestでのテスト
    consumption_request = FactoryBot.create(:consumption_revision_request,
      app: @app,
      requested_user: @user
    )
    
    assert_difference 'consumption_request.comments.count', 1 do
      post :create, params: {
        change_request_id: consumption_request.id,
        comment: {
          content: 'Consumption comment'
        }
      }
    end
    
    # PurchaseCancelRequestでのテスト
    cancel_request = FactoryBot.create(:purchase_cancel_request,
      app: @app,
      requested_user: @user
    )
    
    assert_difference 'cancel_request.comments.count', 1 do
      post :create, params: {
        change_request_id: cancel_request.id,
        comment: {
          content: 'Cancel request comment'
        }
      }
    end
  end

  test "日本語のコメントが正しく処理される" do
    japanese_content = '日本語のコメントです。特殊文字：★●■▼'
    
    assert_difference '@change_request.comments.count', 1 do
      post :create, params: {
        change_request_id: @change_request.id,
        comment: {
          content: japanese_content
        }
      }
    end
    
    created_comment = @change_request.comments.last
    assert { created_comment.content == japanese_content }
  end

  test "特文字を含むコメントが正しく処理される" do
    special_content = 'Special chars: <script>alert("test")</script> & "quotes" & \'single quotes\' 改行\n文字'
    
    assert_difference '@change_request.comments.count', 1 do
      post :create, params: {
        change_request_id: @change_request.id,
        comment: {
          content: special_content
        }
      }
    end
    
    created_comment = @change_request.comments.last
    assert { created_comment.content == special_content }
  end

  test "コメント作成時にPaperTrailで変更履歴が記録される" do
    assert_difference 'PaperTrail::Version.count', 1 do
      post :create, params: {
        change_request_id: @change_request.id,
        comment: {
          content: 'Test comment for paper trail'
        }
      }
    end
    
    # 作成されたVersionがCommentに関連していることを確認
    last_version = PaperTrail::Version.last
    assert { last_version.item_type == 'Comment' }
    assert { last_version.event == 'create' }
  end

  test "polymorphic関連でのコメント作成が正しく動作する" do
    post :create, params: {
      change_request_id: @change_request.id,
      comment: {
        content: 'Polymorphic test comment'
      }
    }
    
    created_comment = @change_request.comments.last
    
    # polymorphic関連の確認
    assert { created_comment.commentable_type == 'ChangeRequest' }
    assert { created_comment.commentable_id == @change_request.id }
    assert { created_comment.commentable == @change_request }
  end

  test "コメント作成失敗時のエラーハンドリング" do
    # バリデーションが失敗するコメントを作成
    # nil contentでバリデーションエラーを発生させる
    assert_no_difference '@change_request.comments.count' do
      post :create, params: {
        change_request_id: @change_request.id,
        comment: {
          content: nil
        }
      }
    end
    
    assert_redirected_to change_request_url(@change_request)
    assert { flash[:alert].present? }
    
    # change_request.errorsが参照されることを確認
    # (コントローラーのエラーハンドリングでchange_request.errors.full_messages.to_sentenceが使われる)
  end

  test "最近のコメントの順序でスコープが適用される" do
    # 複数のコメントを作成
    3.times do |i|
      Comment.create!(
        content: "Comment #{i}",
        user: @user,
        commentable: @change_request
      )
    end
    
    # recentlyスコープでid降順になることを確認
    recent_comments = @change_request.comments.recently
    assert { recent_comments.first.id > recent_comments.last.id }
  end

  test "コメント作成時にTimestampが正しく設定される" do
    freeze_time = Time.current
    
    travel_to freeze_time do
      post :create, params: {
        change_request_id: @change_request.id,
        comment: {
          content: 'Timestamp test comment'
        }
      }
    end
    
    created_comment = @change_request.comments.last
    assert { created_comment.created_at.to_i == freeze_time.to_i }
    assert { created_comment.updated_at.to_i == freeze_time.to_i }
  end
end
