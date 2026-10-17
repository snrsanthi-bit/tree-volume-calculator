# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User registrations', type: :request do
  describe 'GET /users/sign_up' do
    it '一般ユーザー向けの登録画面を公開しない' do
      get '/users/sign_up'

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /users' do
    it '一般ユーザーからの登録を受け付けない' do
      organization = Organization.create!(name: '林業会社A')

      expect do
        post '/users', params: {
          user: {
            name: '不正な管理者',
            email: 'attacker@example.com',
            password: 'password123',
            password_confirmation: 'password123',
            organization_id: organization.id,
            role: 'admin'
          }
        }
      end.not_to change(User, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
