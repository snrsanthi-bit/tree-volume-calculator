require 'rails_helper'

RSpec.describe "Calculator", type: :request do
  describe "GET /" do
    it "正常に表示される" do
      get root_path

      expect(response).to have_http_status(:ok)
    end
  end
end