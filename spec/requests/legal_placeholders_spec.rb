# frozen_string_literal: true

require 'rails_helper'

# 利用規約・プライバシーポリシーに、記入前の印（【】）が残ったまま公開されないようにする
RSpec.describe '利用規約とプライバシーポリシー', type: :request do
  {
    '利用規約' => :terms_path,
    'プライバシーポリシー' => :privacy_policy_path
  }.each do |title, path_name|
    it "#{title}を開ける" do
      get public_send(path_name)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(title)
    end

    it "#{title}に、記入前の印（【】）が残っていない" do
      get public_send(path_name)

      expect(response.body).not_to match(/【.*?】/)
    end
  end

  it 'プライバシーポリシーに、現在地と外部サービスと保存期間の説明がある' do
    get privacy_policy_path

    expect(response.body).to include('現在地', 'OpenStreetMap', 'Google Fonts', '保存期間')
  end
end
