# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '作業範囲の地図操作', type: :system do
  let(:organization) do
    Organization.create!(name: '林業会社A')
  end

  let(:user) do
    User.create!(
      name: '山田太郎',
      email: 'map-test@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      organization: organization
    )
  end

  let(:coordinates) do
    [
      { 'lat' => '34.3853', 'lng' => '132.4553' },
      { 'lat' => '34.3860', 'lng' => '132.4560' },
      { 'lat' => '34.3865', 'lng' => '132.4550' }
    ]
  end

  let(:work_area) do
    organization.work_areas.create!(
      name: '北側作業範囲',
      coordinates: coordinates
    )
  end

  before do
    driven_by :firefox_japan

    visit new_user_session_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'

    visit edit_work_area_path(work_area)
  end

  def click_map_at(lat, lng)
    page.execute_script(<<~JAVASCRIPT, lat, lng)
      const mapElement = document.getElementById("map");
      const map = mapElement._leaflet_map;

      if (!map) {
        throw new Error("Leaflet map instance not found");
      }

      map.fire("click", {
        latlng: L.latLng(arguments[0], arguments[1])
      });
    JAVASCRIPT
  end

  it '地図の空白をクリックすると頂点が追加される' do
    expect(page).to have_css('#work-area-vertex-count', text: '頂点数：3点')

    click_map_at(34.3870, 132.4570)

    expect(page).to have_css('#work-area-vertex-count', text: '頂点数：4点')
  end

  it '既存の頂点をクリックすると選択状態になる' do
    expect(page).to have_css('.outline-vertex')

    page.execute_script(<<~JAVASCRIPT)
      const marker = document.querySelector(".outline-vertex");
      marker.click();
    JAVASCRIPT

    expect(page).to have_css('.outline-vertex.is-selected')
  end

  it '既存の頂点をクリックしても頂点数が増えない' do
    expect(page).to have_css('#work-area-vertex-count', text: '頂点数：3点')

    page.execute_script(<<~JAVASCRIPT)
      const marker = document.querySelector(".outline-vertex");
      marker.click();
    JAVASCRIPT

    expect(page).to have_css('#work-area-vertex-count', text: '頂点数：3点')
  end

  it '地図に追加した頂点が選択状態になる' do
    expect(page).to have_css('#work-area-vertex-count', text: '頂点数：3点')

    click_map_at(34.3870, 132.4570)

    expect(page).to have_css('#work-area-vertex-count', text: '頂点数：4点')

    expect(page).to have_css(
      '.outline-vertex.is-selected',
      count: 1
    )
  end

  it '別の頂点を選択すると前の選択が解除される' do
    page.execute_script(<<~JAVASCRIPT)
      const markers = document.querySelectorAll(".outline-vertex");

      markers[0].click();
    JAVASCRIPT

    expect(page).to have_css('.outline-vertex.is-selected', count: 1)

    page.execute_script(<<~JAVASCRIPT)
      const markers = document.querySelectorAll(".outline-vertex");

      markers[1].click();
    JAVASCRIPT

    expect(page).to have_css('.outline-vertex.is-selected', count: 1)
  end

  it 'Dキーを押すと選択中の頂点が削除される' do
    expect(page).to have_css('#work-area-vertex-count', text: '頂点数：3点')

    page.execute_script(<<~JAVASCRIPT)
      const marker = document.querySelector(".outline-vertex");
      marker.click();
    JAVASCRIPT

    page.find('body').send_keys('d')

    expect(page).to have_css('#work-area-vertex-count', text: '頂点数：2点')
    expect(page).to have_css('.outline-vertex', count: 2)
  end
end
