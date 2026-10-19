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
    it '地積計算画面が正常に表示される' do
      get area_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('地積計算')
    end
  end
end
