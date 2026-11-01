# frozen_string_literal: true

require 'rails_helper'

# 見積の明細は、会社の管理者(admin)だけが、自社の見積の中だけで扱える。
RSpec.describe 'Admin::EstimateLines', type: :request do
  include EstimateSampleHelpers

  def build_user(organization, email, role, name: '山田太郎')
    User.create!(
      name: name, email: email, role: role, organization: organization,
      password: 'password123', password_confirmation: 'password123'
    )
  end

  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:other_organization) { Organization.create!(name: '林業会社B') }
  let(:admin) { build_user(organization, 'admin@example.com', :admin, name: '管理者太郎') }
  let(:estimate) { create_sample_estimate(organization) }
  let(:line) { estimate.estimate_lines.find_by!(name: 'バックホウ') }

  def turbo_stream
    { 'Accept' => 'text/vnd.turbo-stream.html' }
  end

  def worker
    build_user(organization, 'worker@example.com', :worker)
  end

  def cost_item
    category = organization.cost_categories.find_or_create_by!(name: '伐採費')
    category.cost_items.create!(organization: organization, name: '伐採 補助', unit: '人日', unit_price: 20_000)
  end

  describe '未認証・作業者' do
    it '未認証なら明細を足せない' do
      estimate

      expect { post admin_estimate_estimate_lines_path(estimate), params: { estimate_line: { cost_item_id: 1 } } }
        .not_to change(EstimateLine, :count)
      expect(response).to redirect_to(new_user_session_path)
    end

    it '作業者は明細を足せない・変えられない・消せない' do
      line
      item = cost_item
      sign_in worker

      expect do
        post admin_estimate_estimate_lines_path(estimate),
             params: { estimate_line: { cost_item_id: item.id, quantity: 1 } }
      end.not_to change(EstimateLine, :count)
      expect(response).to have_http_status(:forbidden)

      patch admin_estimate_estimate_line_path(estimate, line), params: { estimate_line: { quantity: 99 } }
      expect(line.reload.quantity).to eq(3)

      expect { delete admin_estimate_estimate_line_path(estimate, line) }.not_to change(EstimateLine, :count)
    end
  end

  describe '管理者: 追加' do
    before { sign_in admin }

    it '単価マスタの項目から、名前・区分・単位・単価をコピーして足す。Turbo Streamで明細と集計を更新する' do
      item = cost_item
      estimate

      expect do
        post admin_estimate_estimate_lines_path(estimate),
             params: { estimate_line: { cost_item_id: item.id, quantity: '2' } }, headers: turbo_stream
      end.to change(estimate.estimate_lines, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('estimate_lines').and include('estimate_summary')
      expect(estimate.estimate_lines.last).to have_attributes(
        name: '伐採 補助', unit: '人日', unit_price: 20_000, quantity: 2, cost_category: item.cost_category
      )
    end

    it 'HTMLのリクエストなら、見積の画面へ戻る' do
      item = cost_item

      post admin_estimate_estimate_lines_path(estimate), params: { estimate_line: { cost_item_id: item.id } }

      expect(response).to redirect_to(admin_estimate_path(estimate))
      expect(response).to have_http_status(:see_other)
    end

    it '数量がマイナスなら足さず、エラーをTurbo Streamで返す' do
      item = cost_item
      estimate

      expect do
        post admin_estimate_estimate_lines_path(estimate),
             params: { estimate_line: { cost_item_id: item.id, quantity: '-1' } }, headers: turbo_stream
      end.not_to change(EstimateLine, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('add_line_error').and include('数量は0以上にしてください')
    end

    it '他社の単価マスタの項目は、足せない' do
      other_category = other_organization.cost_categories.create!(name: '伐採費')
      other_item = other_category.cost_items.create!(
        organization: other_organization, name: '他社の項目', unit: '日', unit_price: 1
      )
      estimate

      expect do
        post admin_estimate_estimate_lines_path(estimate),
             params: { estimate_line: { cost_item_id: other_item.id, quantity: 1 } }
      end.not_to change(EstimateLine, :count)
      expect(response).to have_http_status(:not_found)
    end

    it '他社の見積には、明細を足せない' do
      other = create_sample_estimate(other_organization, name: '他社の現場')
      item = cost_item

      expect do
        post admin_estimate_estimate_lines_path(other),
             params: { estimate_line: { cost_item_id: item.id, quantity: 1 } }
      end.not_to change(EstimateLine, :count)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe '管理者: 変更' do
    before { sign_in admin }

    it '数量と単価を変えると、この見積の売価だけが変わる。集計と金額をTurbo Streamで更新する' do
      patch admin_estimate_estimate_line_path(estimate, line),
            params: { estimate_line: { quantity: '4', unit_price: '50,000' } }, headers: turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('estimate_summary').and include('200,000')
      expect(line.reload).to have_attributes(quantity: 4, unit_price: 50_000)
      expect(estimate.reload.calculation.price).to be > 929_000
    end

    it '名前や区分は、パラメータで変えられない' do
      patch admin_estimate_estimate_line_path(estimate, line),
            params: { estimate_line: { quantity: 1, name: '改ざん', unit: '個' } }, headers: turbo_stream

      expect(line.reload).to have_attributes(name: 'バックホウ', unit: '日')
    end

    it 'マイナスなら保存せず、エラーを返す' do
      patch admin_estimate_estimate_line_path(estimate, line),
            params: { estimate_line: { quantity: '-1', unit_price: '-1' } }, headers: turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('数量は0以上にしてください')
      expect(line.reload).to have_attributes(quantity: 3, unit_price: 48_000)
    end

    it '他社の見積の明細は、変えられない' do
      other = create_sample_estimate(other_organization, name: '他社の現場')
      other_line = other.estimate_lines.first

      patch admin_estimate_estimate_line_path(other, other_line), params: { estimate_line: { quantity: 99 } }

      expect(response).to have_http_status(:not_found)
      expect(other_line.reload.quantity).not_to eq(99)
    end

    it '別の見積の明細IDを指定しても、変えられない' do
      other_estimate = Estimate.build_for(organization, name: '別の現場').tap(&:save!)

      patch admin_estimate_estimate_line_path(other_estimate, line), params: { estimate_line: { quantity: 99 } }

      expect(response).to have_http_status(:not_found)
      expect(line.reload.quantity).to eq(3)
    end
  end

  describe '管理者: 削除' do
    before { sign_in admin }

    it '明細を消すと、集計がTurbo Streamで更新される' do
      line

      expect { delete admin_estimate_estimate_line_path(estimate, line), headers: turbo_stream }
        .to change(EstimateLine, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('estimate_lines').and include('estimate_summary')
    end

    it 'HTMLのリクエストなら、見積の画面へ戻る' do
      delete admin_estimate_estimate_line_path(estimate, line)

      expect(response).to redirect_to(admin_estimate_path(estimate))
      expect(response).to have_http_status(:see_other)
    end
  end
end
