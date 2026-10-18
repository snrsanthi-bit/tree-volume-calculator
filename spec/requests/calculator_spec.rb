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
      expect(response.body).to include(work_location.id.to_s)
    end

    it '地図に作業地点のID・緯度・経度を渡す' do
      get area_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-work-locations')
      expect(response.body).to include(work_location.id.to_s)
      expect(response.body).to include('34.3853')
      expect(response.body).to include('132.4553')
    end
  end
end
