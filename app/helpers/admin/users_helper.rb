# frozen_string_literal: true

module Admin
  module UsersHelper
    ROLE_LABELS = { 'admin' => '管理者', 'worker' => '作業者', 'operator' => '運営' }.freeze

    def role_label(role)
      ROLE_LABELS.fetch(role.to_s, role.to_s)
    end

    def assignable_role_options
      User::ACCOUNT_ROLES.map { |role| [role_label(role), role] }
    end
  end
end
