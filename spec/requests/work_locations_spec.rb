# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WorkLocations', type: :request do
  describe 'POST /work_locations' do
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

    let(:valid_params) do
      {
        work_location: {
          name: '作業地点A',
          latitude: 34.3853,
          longitude: 132.4553
        }
      }
    end

    before do
      sign_in user
    end

    it 'ログインユーザーの所属組織に地点情報を保存できる' do
      expect do
        post work_locations_path, params: valid_params
      end.to change(WorkLocation, :count).by(1)

      work_location = WorkLocation.last
      expect(work_location.organization).to eq(organization)
    end

    it '登録成功時にリダイレクトする' do
      post work_locations_path, params: valid_params

      expect(response).to have_http_status(:redirect)
    end

    it '緯度が範囲外なら保存されない' do
      invalid_params = valid_params.deep_dup
      invalid_params[:work_location][:latitude] = 91

      expect do
        post work_locations_path, params: invalid_params
      end.not_to change(WorkLocation, :count)
    end

    it '未ログインの場合は登録されず、ログイン画面へリダイレクトする' do
      expect do
        sign_out user
        post work_locations_path, params: valid_params
      end.not_to change(WorkLocation, :count)

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
