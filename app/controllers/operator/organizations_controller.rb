# frozen_string_literal: true

module Operator
  # 会社・組織の管理と、最初の管理者アカウントの作成（運営だけ）
  class OrganizationsController < BaseController
    include InvitationFlash

    before_action :set_organization, only: %i[show edit update]

    def index
      @organizations = Organization.includes(:users).order(:id)
    end

    def show
      @users = @organization.users.order(:id)
    end

    def new
      @organization = Organization.new
      @admin = @organization.users.build
    end

    def edit; end

    def create
      @organization = Organization.new(organization_params)
      @admin = @organization.users.build(admin_params.merge(role: :admin, password: User.unusable_password))

      if @organization.save
        remember_invitation(@admin)
        redirect_to operator_organization_path(@organization),
                    notice: t('.success', default: '組織と管理者アカウントを作成しました。招待URLを渡してください')
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @organization.update(organization_params)
        redirect_to operator_organization_path(@organization), notice: t('.success', default: '組織を更新しました')
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_organization
      @organization = Organization.find(params.expect(:id))
    end

    def organization_params
      params.expect(organization: [:name])
    end

    def admin_params
      params.expect(admin: %i[name email])
    end
  end
end
