require 'test_helper'

class InheritedResourcesViewsTest < ActionController::TestCase
  # テスト用のダミーコントローラーを作成
  # InheritedResourcesViewsモジュールをincludeしてテスト
  class AppsController < ActionController::Base
    include InheritedResourcesViews
    
    def controller_name
      'apps'
    end
    
    def index
      render plain: 'index'
    end
    
    def show
      render plain: 'show'
    end
    
    def edit
      render plain: 'edit'
    end
  end
  
  # 別のモデルでのテスト用コントローラー
  class UsersController < ActionController::Base
    include InheritedResourcesViews
    
    def controller_name
      'users'
    end
    
    def index
      render plain: 'users index'
    end
  end
  
  # enable_actionsをオーバーライドしたコントローラー
  class CustomActionsController < ActionController::Base
    include InheritedResourcesViews
    
    def enable_actions
      %i(edit show)
    end
    
    def index
      render plain: 'custom index'
    end
  end

  setup do
    # ルーティングの設定
    Rails.application.routes.draw do
      get 'apps/index', to: 'inherited_resources_views_test/apps#index'
      get 'apps/show', to: 'inherited_resources_views_test/apps#show'
      get 'apps/edit', to: 'inherited_resources_views_test/apps#edit'
      get 'users/index', to: 'inherited_resources_views_test/users#index'
      get 'custom_actions/index', to: 'inherited_resources_views_test/custom_actions#index'
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "index_attributesがmodel_attributesからTIME_STAMPSを除いた値を返す" do
    @controller = AppsController.new
    
    get :index
    
    index_attrs = @controller.send(:index_attributes)
    expected_attrs = App.attribute_names.map(&:to_sym) - InheritedResourcesViews::TIME_STAMPS
    
    assert { index_attrs == expected_attrs }
    assert { !index_attrs.include?(:created_at) }
    assert { !index_attrs.include?(:updated_at) }
  end

  test "show_attributesがmodel_attributesの全ての値を返す" do
    @controller = AppsController.new
    
    get :show
    
    show_attrs = @controller.send(:show_attributes)
    expected_attrs = App.attribute_names.map(&:to_sym)
    
    assert { show_attrs == expected_attrs }
    assert { show_attrs.include?(:created_at) }
    assert { show_attrs.include?(:updated_at) }
  end

  test "edit_attributesがid、created_at、updated_atを除いた値を返す" do
    @controller = AppsController.new
    
    get :edit
    
    edit_attrs = @controller.send(:edit_attributes)
    expected_attrs = App.attribute_names.map(&:to_sym) - %i(id) - InheritedResourcesViews::TIME_STAMPS
    
    assert { edit_attrs == expected_attrs }
    assert { !edit_attrs.include?(:id) }
    assert { !edit_attrs.include?(:created_at) }
    assert { !edit_attrs.include?(:updated_at) }
  end

  test "enable_actionsがDEFAULT_ENABLE_ACTIONSを返す" do
    @controller = AppsController.new
    
    get :index
    
    enabled_actions = @controller.send(:enable_actions)
    expected_actions = InheritedResourcesViews::DEFAULT_ENABLE_ACTIONS
    
    assert { enabled_actions == expected_actions }
    assert { enabled_actions == %i(new edit delete) }
  end

  test "link_attributesがDEFAULT_LINK_ATTRIBUTESを返す" do
    @controller = AppsController.new
    
    get :index
    
    link_attrs = @controller.send(:link_attributes)
    expected_attrs = InheritedResourcesViews::DEFAULT_LINK_ATTRIBUTES
    
    assert { link_attrs == expected_attrs }
    assert { link_attrs == %i(id) }
  end

  test "model_attributesが正しいモデルの属性を返す" do
    @controller = AppsController.new
    
    get :index
    
    model_attrs = @controller.send(:model_attributes)
    expected_attrs = App.attribute_names.map(&:to_sym)
    
    assert { model_attrs == expected_attrs }
    
    # Appモデルの主要な属性が含まれることを確認
    assert { model_attrs.include?(:id) }
    assert { model_attrs.include?(:name) }
    assert { model_attrs.include?(:identifier) }
    assert { model_attrs.include?(:created_at) }
    assert { model_attrs.include?(:updated_at) }
  end

  test "異なるコントローラーで異なるモデルの属性が取得される" do
    @controller = UsersController.new
    
    get :index
    
    model_attrs = @controller.send(:model_attributes)
    expected_attrs = User.attribute_names.map(&:to_sym)
    
    assert { model_attrs == expected_attrs }
    
    # Userモデルの主要な属性が含まれることを確認
    assert { model_attrs.include?(:id) }
    assert { model_attrs.include?(:email) }
    assert { model_attrs.include?(:role) }
    assert { model_attrs.include?(:name) }
  end

  test "定数が正しく定義されている" do
    assert { InheritedResourcesViews::DEFAULT_ENABLE_ACTIONS == %i(new edit delete) }
    assert { InheritedResourcesViews::DEFAULT_LINK_ATTRIBUTES == %i(id) }
    assert { InheritedResourcesViews::TIME_STAMPS == %i(created_at updated_at) }
  end

  test "TIME_STAMPSが配列の減算で正しく動作する" do
    sample_attributes = %i(id name email created_at updated_at role)
    result = sample_attributes - InheritedResourcesViews::TIME_STAMPS
    
    expected = %i(id name email role)
    assert { result == expected }
  end

  test "helper_methodが正しく設定される" do
    helper_methods = AppsController._helper_methods
    
    # 全てのメソッドがヘルパーメソッドとして登録されていることを確認
    assert { helper_methods.include?(:index_attributes) }
    assert { helper_methods.include?(:show_attributes) }
    assert { helper_methods.include?(:edit_attributes) }
    assert { helper_methods.include?(:enable_actions) }
    assert { helper_methods.include?(:link_attributes) }
  end

  test "enable_actionsをオーバーライドできる" do
    @controller = CustomActionsController.new
    
    get :index
    
    enabled_actions = @controller.send(:enable_actions)
    
    # オーバーライドれた値が返されることを確認
    assert { enabled_actions == %i(edit show) }
    assert { enabled_actions != InheritedResourcesViews::DEFAULT_ENABLE_ACTIONS }
  end

  test "各attributesメソッドで重複が除去される" do
    @controller = AppsController.new
    
    get :index
    
    # index_attributes
    index_attrs = @controller.send(:index_attributes)
    assert { index_attrs.uniq == index_attrs }
    
    # show_attributes
    show_attrs = @controller.send(:show_attributes)
    assert { show_attrs.uniq == show_attrs }
    
    # edit_attributes
    edit_attrs = @controller.send(:edit_attributes)
    assert { edit_attrs.uniq == edit_attrs }
  end

  test "privateメソッドが外部から呼び出せない" do
    @controller = AppsController.new
    
    # model_attributesがprivateメソッドであることを確認
    assert_raises(NoMethodError) do
      @controller.model_attributes
    end
  end

  test "各属性メソッドが配列を返す" do
    @controller = AppsController.new
    
    get :index
    
    assert { @controller.send(:index_attributes).is_a?(Array) }
    assert { @controller.send(:show_attributes).is_a?(Array) }
    assert { @controller.send(:edit_attributes).is_a?(Array) }
    assert { @controller.send(:enable_actions).is_a?(Array) }
    assert { @controller.send(:link_attributes).is_a?(Array) }
  end

  test "シンボル形式で属性が返される" do
    @controller = AppsController.new
    
    get :index
    
    index_attrs = @controller.send(:index_attributes)
    show_attrs = @controller.send(:show_attributes)
    edit_attrs = @controller.send(:edit_attributes)
    
    # 全ての要素がシンボルであることを確認
    assert { index_attrs.all? { |attr| attr.is_a?(Symbol) } }
    assert { show_attrs.all? { |attr| attr.is_a?(Symbol) } }
    assert { edit_attrs.all? { |attr| attr.is_a?(Symbol) } }
  end

  test "controller_nameとモデル名の対応関係" do
    # Appsコントローラー（controller_name: apps）
    @controller = AppsController.new
    assert { @controller.controller_name == 'apps' }
    
    # Usersコントローラー（controller_name: users）
    @controller = UsersController.new
    assert { @controller.controller_name == 'users' }
  end

  test "フリーズされた定数を変更できない" do
    # frozen?を確認
    assert { InheritedResourcesViews::DEFAULT_ENABLE_ACTIONS.frozen? }
    assert { InheritedResourcesViews::DEFAULT_LINK_ATTRIBUTES.frozen? }
    assert { InheritedResourcesViews::TIME_STAMPS.frozen? }
    
    # 変更を試みてもエラーが発生することを確認
    assert_raises(FrozenError) do
      InheritedResourcesViews::DEFAULT_ENABLE_ACTIONS << :custom
    end
  end

  test "複数回呼び出しても同じ結果が返される" do
    @controller = AppsController.new
    
    get :index
    
    # 複数回呼び出して同じ結果が返されることを確認
    first_call = @controller.send(:index_attributes)
    second_call = @controller.send(:index_attributes)
    
    assert { first_call == second_call }
    
    # show_attributes
    first_show = @controller.send(:show_attributes)
    second_show = @controller.send(:show_attributes)
    
    assert { first_show == second_show }
  end

  test "継承関係でのモジュールの動作" do
    # 親クラスでincludeしたモジュールが子クラスでも動作することを確認
    child_controller_class = Class.new(AppsController) do
      def custom_action
        render plain: 'child'
      end
    end
    
    child_controller = child_controller_class.new
    
    # モジュールのメソッドが継承されていることを確認
    assert { child_controller.respond_to?(:index_attributes, true) }
    assert { child_controller.respond_to?(:show_attributes, true) }
    assert { child_controller.respond_to?(:edit_attributes, true) }
  end

  test "ActiveSupport::Concernの動作確認" do
    # included do ブロックが正しく実行されることを確認
    assert { AppsController.ancestors.include?(InheritedResourcesViews) }
    
    # helper_methodsが設定されていることを確認
    helper_methods = AppsController._helper_methods
    expected_methods = %i(index_attributes show_attributes edit_attributes enable_actions link_attributes)
    
    expected_methods.each do |method|
      assert { helper_methods.include?(method) }
    end
  end
end
