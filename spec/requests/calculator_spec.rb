# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Calculator', type: :request do
  describe 'GET /' do
    it '正常に表示される' do
      get root_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /area' do
    let(:organization) { Organization.create!(name: '林業会社A') }
    let(:user) do
      User.create!(
        name: '山田太郎',
        email: 'user@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        organization: organization
      )
    end

    let!(:work_location) do
      WorkLocation.create!(
        name: '作業地点A',
        latitude: 34.3853,
        longitude: 132.4553,
        organization: organization
      )
    end

    before do
      sign_in user
      work_location
    end

    it '所属組織の作業地点を取得して表示する' do
      get area_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('作業地点A')
    end
  end
end
