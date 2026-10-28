# frozen_string_literal: true

# 権限(role)による画面・操作の制限。許可されない権限のユーザーには 403 を返す。
#
#   operator = 運営 / admin = 会社の管理者 / worker = 作業者
module RoleAuthorization
  extend ActiveSupport::Concern

  private

  def require_roles!(*roles)
    return if roles.map(&:to_s).include?(current_user.role)

    render 'errors/forbidden', status: :forbidden
  end
end
