# frozen_string_literal: true

module Operator
  # 組織のアカウント（管理者・作業者）の作成と、招待URLの再発行（運営だけ）。
  # 運営アカウントは画面から作らない・触れない。
  class UsersController < BaseController
    include InvitationFlash

    before_action :set_organization

    def new
      @user = @organization.users.new
    end

    def create
      @user = @organization.users.new(user_params.merge(password: User.unusable_password))

      if @user.save
        remember_invitation(@user)
        redirect_to operator_organization_path(@organization),
                    notice: t('.success', default: 'アカウントを作成しました。招待URLを本人に渡してください')
      else
        render :new, status: :unprocessable_content
      end
    end

    # 招待URLの再発行（前のURLは使えなくなる）
    def invitation
      user = @organization.users.where.not(role: :operator).find(params.expect(:id))

      remember_invitation(user)
      redirect_to operator_organization_path(@organization), notice: t('.success', default: '招待URLを再発行しました')
    end

    private

    def set_organization
      @organization = Organization.find(params.expect(:organization_id))
    end

    # 組織は URL で決まる。権限は管理者・作業者のどちらかだけ（運営は付与できない）
    def user_params
      permitted = params.expect(user: %i[name email role])
      permitted.delete(:role) unless User::ACCOUNT_ROLES.include?(permitted[:role])
      permitted
    end
  end
end
