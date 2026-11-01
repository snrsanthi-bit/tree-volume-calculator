# frozen_string_literal: true

require 'rails_helper'

# 単価マスタは、会社の管理者(admin)だけが、自社の分だけ扱える。
RSpec.describe 'Admin::CostItems', type: :request do
  def build_user(organization, email, role, name: '山田太郎')
    User.create!(
      name: name, email: email, role: role, organization: organization,
      password: 'password123', password_confirmation: 'password123'
    )
  end

  def item_params(overrides = {})
    { cost_item: { name: '伐採 人工', cost_category_id: category.id, unit: '人日', unit_price: '28000' }.merge(overrides) }
  end

  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:other_organization) { Organization.create!(name: '林業会社B') }
  let(:admin) { build_user(organization, 'admin@example.com', :admin, name: '管理者太郎') }
  let(:worker) { build_user(organization, 'worker@example.com', :worker) }
  let(:category) { organization.cost_categories.create!(name: '伐採費') }

  def create_item(owner = organization, owner_category = category, name: '伐採 人工')
    owner.cost_items.create!(cost_category: owner_category, name: name, unit: '人日', unit_price: 28_000)
  end

  describe '未認証・作業者・運営' do
    it '未認証ならログイン画面へ移動し、項目も作れない' do
      get admin_cost_items_path
      expect(response).to redirect_to(new_user_session_path)

      expect { post admin_cost_items_path, params: item_params }.not_to change(CostItem, :count)
    end

    it '作業者は一覧を開けず、項目も作れない・消せない' do
      item = create_item
      sign_in worker

      get admin_cost_items_path
      expect(response).to have_http_status(:forbidden)

      expect { post admin_cost_items_path, params: item_params }.not_to change(CostItem, :count)
      expect { delete admin_cost_item_path(item) }.not_to change(CostItem, :count)
    end

    it '運営(operator)も使えない' do
      sign_in build_user(organization, 'operator@example.com', :operator)

      get admin_cost_items_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe '管理者' do
    before { sign_in admin }

    it '自社の項目を区分ごとに表示し、他社の項目は表示しない' do
      create_item
      create_item(other_organization, other_organization.cost_categories.create!(name: '他社の区分'), name: '他社の項目')

      get admin_cost_items_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('伐採費', '伐採 人工', '28,000円')
      expect(response.body).not_to include('他社の区分', '他社の項目')
    end

    it '区分が1つもないときは、先に区分を登録するよう案内する' do
      get new_admin_cost_item_path

      expect(response).to redirect_to(admin_cost_categories_path)
      expect(flash[:alert]).to be_present
    end

    it '項目を追加できる' do
      category

      expect { post admin_cost_items_path, params: item_params }.to change(organization.cost_items, :count).by(1)

      expect(response).to redirect_to(admin_cost_items_path)
      expect(organization.cost_items.last).to have_attributes(name: '伐採 人工', unit: '人日', unit_price: 28_000)
    end

    it '単価を全角数字・カンマ区切りで入力しても、追加できる' do
      category

      post admin_cost_items_path, params: item_params(unit_price: '２８，０００')

      expect(response).to redirect_to(admin_cost_items_path)
      expect(organization.cost_items.last.unit_price).to eq(28_000)
    end

    it '単価がマイナス・小数、項目名が空のときは追加せず、エラーを表示する' do
      category

      expect { post admin_cost_items_path, params: item_params(unit_price: '-1') }.not_to change(CostItem, :count)
      expect(response).to have_http_status(:unprocessable_content)

      expect { post admin_cost_items_path, params: item_params(unit_price: '1.5') }.not_to change(CostItem, :count)
      expect { post admin_cost_items_path, params: item_params(name: '') }.not_to change(CostItem, :count)
      expect(response.body).to include('を入力してください')
    end

    it '他社の区分は指定できない' do
      other_category = other_organization.cost_categories.create!(name: '他社の区分')

      expect { post admin_cost_items_path, params: item_params(cost_category_id: other_category.id) }
        .not_to change(CostItem, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it '項目を更新できる' do
      item = create_item

      patch admin_cost_item_path(item), params: item_params(unit_price: '30000')

      expect(response).to redirect_to(admin_cost_items_path)
      expect(item.reload.unit_price).to eq(30_000)
    end

    it '項目を削除できる' do
      item = create_item

      expect { delete admin_cost_item_path(item) }.to change(CostItem, :count).by(-1)
      expect(response).to redirect_to(admin_cost_items_path)
    end
  end

  describe '他社の項目' do
    it '編集・更新・削除のどれも404になり、変更されない' do
      other_item = create_item(other_organization, other_organization.cost_categories.create!(name: '他社の区分'))
      category

      sign_in admin
      get edit_admin_cost_item_path(other_item)
      expect(response).to have_http_status(:not_found)

      sign_in admin
      patch admin_cost_item_path(other_item), params: item_params(name: '乗っ取り')
      expect(response).to have_http_status(:not_found)

      sign_in admin
      delete admin_cost_item_path(other_item)
      expect(response).to have_http_status(:not_found)
      expect(other_item.reload.name).to eq('伐採 人工')
    end
  end
end
