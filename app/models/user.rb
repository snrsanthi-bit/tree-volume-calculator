# frozen_string_literal: true

class User < ApplicationRecord
  # 招待URL（= パスワード設定用の使い捨てトークン）の有効期間
  INVITATION_VALID_FOR = 7.days

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         reset_password_within: INVITATION_VALID_FOR

  # 運営が、組織の画面でアカウントに付与できる権限（運営アカウント自体は画面から作らない）
  ACCOUNT_ROLES = %w[admin worker].freeze

  belongs_to :organization

  enum :role, {
    operator: 0,
    admin: 1,
    worker: 2
  }, default: :worker

  validates :name, presence: true

  # 誰にも知らされないパスワード。招待されるまで、そのアカウントではログインできない
  def self.unusable_password
    SecureRandom.base58(32)
  end

  # 招待URL用のトークンを発行して返す。再発行すると、前のURLは使えなくなる。
  # 画面で本人がパスワードを設定すると、トークンは使えなくなる（使い捨て）。
  def issue_invitation_token!
    set_reset_password_token
  end
end
