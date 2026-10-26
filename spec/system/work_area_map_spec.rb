# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '作業範囲の地図操作', type: :system do
  def delete_first_auxiliary_point
    click_button '補助点'

    page.execute_script(<<~JAVASCRIPT)
      document.querySelectorAll(".auxiliary-point")[0].click();
      document.dispatchEvent(
        new KeyboardEvent("keydown", {
          key: "d",
          bubbles: true
        })
      );
    JAVASCRIPT
  end

  def create_auxiliary_line
    click_button '補助点'
    click_map_at(34.3857, 132.4555)
    click_map_at(34.3858, 132.4557)
    click_button '補助線'

    page.execute_script(<<~JAVASCRIPT)
      const points = document.querySelectorAll(".auxiliary-point");
      points[0].click();
      points[1].click();
    JAVASCRIPT
  end

  def auxiliary_line_survey_data
    JSON.parse(
      page.find_by_id(
        'work-area-survey-data',
        visible: :all
      ).value
    )
  end

  def expect_auxiliary_line_saved(survey_data)
    expect(survey_data['auxiliary_lines']).to contain_exactly(
      hash_including(
        'start_point_id' => 'point-1',
        'end_point_id' => 'point-2'
      )
    )
  end

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

  let(:survey_data_with_auxiliary_line) do
    {
      auxiliary_points: [
        { id: 'point-1', lat: 34.3857, lng: 132.4555 },
        { id: 'point-2', lat: 34.3858, lng: 132.4557 }
      ],
      auxiliary_lines: [
        {
          id: 'line-1',
          start_point_id: 'point-1',
          end_point_id: 'point-2'
        }
      ]
    }
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

  def monitor_triangulation_api
    page.execute_script(<<~JAVASCRIPT)
      window.triangulationApiCalls = 0;

      const originalFetch = window.fetch.bind(window);

      window.fetch = (...args) => {
        if (args[0].toString().includes('/area/triangulate')) {
          window.triangulationApiCalls += 1;
        }

        return originalFetch(...args);
      };
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

  context 'when in auxiliary point mode' do
    before do
      click_button '補助点'
    end

    it '地図をクリックすると補助点が追加されるが外周点数は変わらない' do
      coordinates_input = 'input[name="work_area[coordinates]"]'
      original_coordinates = page.find(coordinates_input, visible: :all).value

      click_map_at(34.38593, 132.45543)

      expect(page).to have_css('.auxiliary-point', count: 1)
      expect(page).to have_css(
        '#work-area-vertex-count',
        text: '頂点数：3点'
      )
      expect(
        page.find(
          'input[name="work_area[coordinates]"]',
          visible: :all
        ).value
      ).to eq(original_coordinates)
    end

    it '補助点をクリックすると選択状態になる' do
      click_map_at(34.38593, 132.45543)

      page.execute_script(<<~JAVASCRIPT)
        document.querySelector(".auxiliary-point").click();
      JAVASCRIPT

      expect(page).to have_css('.auxiliary-point.is-selected')
    end

    it 'Dキーを押すと選択中の補助点が削除される' do
      click_map_at(34.38593, 132.45543)

      page.execute_script(<<~JAVASCRIPT)
        document.querySelector(".auxiliary-point").click();
      JAVASCRIPT

      page.find('body').send_keys('d')

      expect(page).to have_no_css('.auxiliary-point')
      expect(page).to have_css('.outline-vertex', count: 3)
      expect(page).to have_css(
        '#work-area-vertex-count',
        text: '頂点数：3点'
      )
    end

    it '外周の外側をクリックすると補助点が追加されずメッセージが表示される' do
      click_map_at(34.3900, 132.4600)

      expect(page).to have_no_css('.auxiliary-point')
      expect(page).to have_css(
        '#work-area-message',
        text: '外周の内側に配置してください'
      )
    end
  end

  context 'when viewing the detail page' do
    let(:survey_data_with_auxiliary_line) do
      {
        auxiliary_points: [
          { id: 'point-1', lat: 34.3857, lng: 132.4555 },
          { id: 'point-2', lat: 34.3858, lng: 132.4557 }
        ],
        auxiliary_lines: [
          {
            id: 'line-1',
            start_point_id: 'point-1',
            end_point_id: 'point-2'
          }
        ]
      }
    end

    it '初期表示時に三角分割APIを呼び出さない' do
      monitor_triangulation_api

      page.execute_script(
        "Turbo.visit(#{work_area_path(work_area).to_json})"
      )

      expect(page).to have_css('#map')
      expect(page.evaluate_script('window.triangulationApiCalls')).to eq(0)
    end

    it '保存済みの補助線を詳細画面に表示する' do
      work_area.update!(survey_data: survey_data_with_auxiliary_line)

      visit work_area_path(work_area)

      expect(page).to have_css('.auxiliary-line', count: 1)
    end
  end

  context 'when in auxiliary line mode' do
    it '補助線モードのボタンが表示される' do
      expect(page).to have_button('補助線')
    end
  end

  it '補助線ボタンを押すと補助線モードに切り替わる' do
    click_button '補助線'

    expect(
      page.find_by_id('auxiliary-line-mode-button')['aria-pressed']
    ).to eq('true')

    expect(
      page.find_by_id('outline-mode-button')['aria-pressed']
    ).to eq('false')

    expect(page).to have_css(
      '#work-area-message',
      text: '補助線モード'
    )
  end

  it '補助線モードで補助点を2つ選択すると補助線が作成される' do
    click_button '補助点'
    click_map_at(34.3857, 132.4555)
    click_map_at(34.3858, 132.4557)

    expect(page).to have_css('.auxiliary-point', count: 2)

    click_button '補助線'

    page.execute_script(<<~JAVASCRIPT)
      const points = document.querySelectorAll(".auxiliary-point");
      points[0].click();
      points[1].click();
    JAVASCRIPT

    expect(page).to have_css('.auxiliary-line', count: 1)
  end

  it '作成した補助線が保存用データに記録される' do
    create_auxiliary_line

    survey_data = auxiliary_line_survey_data
    expect(survey_data['auxiliary_lines']).to contain_exactly(
      hash_including(
        'start_point' => {
          'type' => 'auxiliary',
          'id' => 'point-1'
        },
        'end_point' => {
          'type' => 'auxiliary',
          'id' => 'point-2'
        }
      )
    )
  end

  it '補助点を削除すると接続している補助線も削除される' do
    create_auxiliary_line
    expect(page).to have_css('.auxiliary-line', count: 1)

    delete_first_auxiliary_point

    expect(page).to have_css('.auxiliary-point', count: 1)
    expect(page).to have_no_css('.auxiliary-line')
    expect(auxiliary_line_survey_data['auxiliary_lines']).to be_empty
  end

  it '保存済みの補助線を編集画面に表示する' do
    work_area.update!(survey_data: survey_data_with_auxiliary_line)

    visit edit_work_area_path(work_area)

    expect(page).to have_css('.auxiliary-line', count: 1)
  end

  it '外周点と補助点を選択すると補助線が作成される' do
    click_button '補助点'
    click_map_at(34.3857, 132.4555)

    click_button '補助線'

    page.execute_script(<<~JAVASCRIPT)
      const outlinePoint = document.querySelector(".outline-vertex");
      const auxiliaryPoint = document.querySelector(".auxiliary-point");

      outlinePoint.click();
      auxiliaryPoint.click();
    JAVASCRIPT

    expect(page).to have_css('.auxiliary-line', count: 1)
  end
end
