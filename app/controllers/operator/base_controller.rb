# frozen_string_literal: true

module Operator
  # 運営(operator)用の画面の共通処理。会社の管理者・作業者は使えない。
  class BaseController < ApplicationController
    include RoleAuthorization

    before_action :authenticate_user!
    before_action { require_roles!(:operator) }
  end
end
