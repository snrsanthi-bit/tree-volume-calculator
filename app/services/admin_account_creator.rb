# frozen_string_literal: true

# 会社(組織)とそのアカウント（既定は管理者）を作る。本番の最初の管理者・運営アカウントを作るときに使う。
# パスワードは誰も知らない状態で作り、招待トークン（本人がパスワードを設定するURL用）を返す。
# 使い方は lib/tasks/accounts.rake を参照。
class AdminAccountCreator
  Result = Struct.new(:user, :invitation_token)

  def self.call(organization_name:, name:, email:, role: :admin)
    new(organization_name, name, email, role).call
  end

  def initialize(organization_name, name, email, role)
    @organization_name = organization_name
    @name = name
    @email = email
    @role = role
  end

  def call
    ActiveRecord::Base.transaction do
      organization = Organization.find_or_create_by!(name: @organization_name)
      user = organization.users.create!(
        name: @name, email: @email, role: @role, password: User.unusable_password
      )

      Result.new(user, user.issue_invitation_token!)
    end
  end
end
