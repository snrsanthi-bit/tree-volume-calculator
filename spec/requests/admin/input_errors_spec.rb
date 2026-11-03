# frozen_string_literal: true

require 'rails_helper'

# 入力エラーのとき、管理者用の画面が、保存せずに画面を出し直す（またはメッセージ付きで戻る）
RSpec.describe 'Admin 画面の入力エラー', type: :request do
  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:category) { organization.cost_categories.create!(name: '伐採費') }
  let(:cost_item) do
    organization.cost_items.create!(name: '人工', cost_category: category, unit: '人日', unit_price: 20_000)
  end

  before do
    sign_in User.create!(
      name: '管理者太郎', email: 'admin@example.com', role: :admin, organization: organization,
      password: 'password123', password_confirmation: 'password123'
    )
  end

  it '区分の名前を空にして更新すると、編集画面が出し直され、名前は変わらない' do
    patch admin_cost_category_path(category), params: { cost_category: { name: '' } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(category.reload.name).to eq('伐採費')
  end

  it '項目の新規画面が出る（区分があるとき）' do
    category

    get new_admin_cost_item_path

    expect(response).to have_http_status(:ok)
  end

  it '項目の名前を空にして更新すると、編集画面が出し直され、名前は変わらない' do
    patch admin_cost_item_path(cost_item), params: { cost_item: { name: '' } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(cost_item.reload.name).to eq('人工')
  end

  it '明細の数量が正しくないと、通常の画面ではエラーメッセージ付きで見積へ戻り、明細は増えない' do
    estimate = Estimate.build_for(organization, name: '現場A').tap(&:save!)

    post admin_estimate_estimate_lines_path(estimate),
         params: { estimate_line: { cost_item_id: cost_item.id, quantity: -1 } }

    expect(response).to redirect_to(admin_estimate_path(estimate))
    expect(response).to have_http_status(:see_other)
    expect(flash[:alert]).to be_present
    expect(estimate.estimate_lines.count).to eq(0)
  end
end
