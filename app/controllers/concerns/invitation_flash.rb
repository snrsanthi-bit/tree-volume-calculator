# frozen_string_literal: true

# 招待URLを発行し、次の画面で一度だけ表示する（保存しない）。
# URLは Devise のパスワード再設定トークン。7日間・1回のみ有効で、再発行すると前のURLは使えなくなる。
module InvitationFlash
  private

  def remember_invitation(user)
    token = user.issue_invitation_token!

    flash[:invitation] = {
      'name' => user.name, 'email' => user.email,
      'url' => edit_user_password_url(reset_password_token: token)
    }
  end
end
