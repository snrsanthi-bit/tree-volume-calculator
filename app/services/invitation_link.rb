# frozen_string_literal: true

# 招待URLを組み立てる（画面以外＝rake タスクからも使う）
module InvitationLink
  def self.url(token, base_url)
    path = Rails.application.routes.url_helpers.edit_user_password_path(reset_password_token: token)

    "#{base_url.to_s.chomp('/')}#{path}"
  end
end
