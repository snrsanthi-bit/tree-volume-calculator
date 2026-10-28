# frozen_string_literal: true

module Admin
  # 自社の作業者(worker)を管理する。管理者アカウントの作成・権限の変更は運営だけの仕事。
  # 他社のユーザーや、作業者以外のユーザーは find で見つからず 404 になる。
  class UsersController < BaseController
    include InvitationFlash

    before_action :set_user, only: %i[edit update invitation]

    def index
      @users = worker_users.order(:id)
    end

    def new
      @user = worker_users.new
    end

    def edit; end

    def create
      @user = current_user.organization.users.new(user_params.merge(role: :worker, password: User.unusable_password))

      if @user.save
        remember_invitation(@user)
        redirect_to admin_users_path, notice: t('.success', default: 'ユーザーを作成しました。招待URLを本人に渡してください')
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @user.update(user_params)
        redirect_to admin_users_path, notice: t('.success', default: 'ユーザーを更新しました')
      else
        render :edit, status: :unprocessable_content
      end
    end

    # 招待URLの再発行（前のURLは使えなくなる）。パスワードを忘れたときもこれで再設定できる
    def invitation
      remember_invitation(@user)
      redirect_to admin_users_path, notice: t('.success', default: '招待URLを再発行しました。本人に渡してください')
    end

    private

    def worker_users
      current_user.organization.users.worker
    end

    def set_user
      @user = worker_users.find(params.expect(:id))
    end

    # 会社(organization_id)と権限(role)は受け付けない。常に自社の作業者
    def user_params
      params.expect(user: %i[name email])
    end
  end
end
