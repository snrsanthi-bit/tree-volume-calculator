# frozen_string_literal: true

# ログイン中のユーザーが、自分のパスワードを変更する（現在のパスワードが必要）。
class AccountPasswordsController < ApplicationController
  before_action :authenticate_user!

  def edit; end

  def update
    if change_password
      bypass_sign_in(current_user) # パスワード変更でログアウトされないようにする
      redirect_to root_path, notice: t('.success', default: 'パスワードを変更しました')
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def change_password
    attributes = password_params

    # Devise の update_with_password は、新しいパスワードが空だと何も変えずに成功扱いにするため、先に弾く
    if attributes[:password].blank?
      current_user.errors.add(:password, :blank)
      return false
    end

    current_user.update_with_password(attributes)
  end

  def password_params
    params.expect(user: %i[current_password password password_confirmation])
  end
end
