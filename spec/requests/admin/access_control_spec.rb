# frozen_string_literal: true

require 'rails_helper'

# 管理者用の画面（/admin 配下）は、どの経路でも、会社の管理者だけが入れる。
# 経路はルーティングから拾う。あとで画面を足したときに、管理者用の共通処理（Admin::BaseController）を
# 継承し忘れると、ここで落ちて気づける。
RSpec.describe 'Admin 画面のアクセス制限', type: :request do
  def build_user(role)
    User.create!(
      name: '山田太郎', email: "#{role}@example.com", role: role, organization: Organization.create!(name: '林業会社A'),
      password: 'password123', password_confirmation: 'password123'
    )
  end

  # [HTTPメソッド, パス] の一覧。パスの :id などは 1 にする（権限の確認は、見積を探す前に行われる）
  def admin_routes
    Rails.application.routes.routes.filter_map do |route|
      next unless route.defaults[:controller].to_s.start_with?('admin/')

      [route.verb, route.path.spec.to_s.sub('(.:format)', '').gsub(/:\w+/, '1')]
    end.uniq
  end

  it 'ルーティングから、見積まわりの管理者用の経路を拾えている' do
    paths = admin_routes.map(&:last)

    expect(paths).to include(
      admin_estimates_path, admin_estimate_path(1), admin_estimate_submission_path(1),
      admin_estimate_estimate_lines_path(1), edit_admin_estimate_setting_path,
      admin_cost_categories_path, admin_cost_items_path
    )
    expect(admin_routes.map(&:first).uniq).to include('GET', 'POST', 'PATCH', 'DELETE')
  end

  it '未認証なら、どの経路もログイン画面へ移動する' do
    aggregate_failures do
      admin_routes.each do |verb, path|
        public_send(verb.downcase, path)

        expect(response).to redirect_to(new_user_session_path), "未認証: #{verb} #{path}"
      end
    end
  end

  %i[worker operator].each do |role|
    it "#{role}は、どの経路にも入れない（403）" do
      sign_in build_user(role)

      aggregate_failures do
        admin_routes.each do |verb, path|
          public_send(verb.downcase, path)

          expect(response).to have_http_status(:forbidden), "#{role}: #{verb} #{path}"
        end
      end
    end
  end
end
