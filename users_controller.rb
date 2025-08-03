# == Schema Information
#
# Table name: users
#
#  id               :integer          not null, primary key
#  email            :string(255)      not null
#  role             :string(255)      not null
#  last_accessed_at :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  name             :string(255)
#

class UsersController < ApplicationController
  before_action :set_user, only: [:show, :edit, :update]

  # InheritedResourcesViewsモジュールの機能をヘルパーメソッドとして移植
  helper_method :index_attributes, :show_attributes, :edit_attributes, :enable_actions

  def index
    @users = User.all
  end

  def show
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    
    if @user.save
      redirect_to @user, notice: 'User was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to @user, notice: 'User was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email, :name, :role)
  end

  # InheritedResourcesViewsモジュールから移植したヘルパーメソッド
  def index_attributes
    %i(id email name role last_accessed_at)
  end

  def show_attributes
    %i(id email name role last_accessed_at created_at updated_at)
  end

  def edit_attributes
    %i(email name role)
  end

  def enable_actions
    %i(new edit)
  end
end
