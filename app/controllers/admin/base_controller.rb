# frozen_string_literal: true

module Admin
  # 会社の管理者(admin)用の画面の共通処理。運営(operator)・作業者(worker)は使えない。
  class BaseController < ApplicationController
    include RoleAuthorization

    before_action :authenticate_user!
    before_action { require_roles!(:admin) }
  end
end
