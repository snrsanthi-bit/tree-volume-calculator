# frozen_string_literal: true

require 'rails_helper'
require 'support/survey_map_helpers'

RSpec.describe '作業範囲の地図操作', type: :system do
  include SurveyMapHelpers

  def survey_data_field
    JSON.parse(page.find_by_id('work-area-survey-data', visible: :all).value)
  end

  def click_map_at(lat, lng)
    page.execute_script(<<~JAVASCRIPT, lat, lng)
      const map = document.getElementById("map")?._leaflet_map;
      if (!map) { throw new Error("Leaflet map instance not found"); }
      map.fire("click", { latlng: L.latLng(arguments[0], arguments[1]) });
    JAVASCRIPT
  end

  def wait_for_proposal
    expect(page).to have_css('#map[data-triangulation-ready="true"]')
  end

  def centroid
    [(34.3853 + 34.3860 + 34.3865) / 3, (132.4553 + 132.4560 + 132.4550) / 3]
  end

  def connect_line(from_selector, to_selector)
    click_button '補助線'
    page.execute_script(<<~JAVASCRIPT, from_selector, to_selector)
      document.querySelector(arguments[0]).click();
      document.querySelector(arguments[1]).click();
    JAVASCRIPT
  end

  # ---- 実測値の保護用ヘルパー ---------------------------------------------
  # window.confirm を差し替え、呼ばれた回数と文言を記録する(answer: true=続ける / false=キャンセル)
  def stub_confirm(answer)
    page.execute_script(<<~JAVASCRIPT, answer)
      const answer = arguments[0];
      window.confirmMessages = [];
      window.confirm = (message) => { window.confirmMessages.push(message); return answer; };
    JAVASCRIPT
  end

  def confirm_messages
    page.evaluate_script('window.confirmMessages')
  end

  # 保存用データの線を「端点ID(昇順)」→ 実測値 のハッシュにする
  def measured_by_pair
    survey_data_field['lines'].to_h do |l|
      [[l['from'], l['to']].sort.join('|'), l['measured_length']]
    end
  end

  def open_edit_with_measured_triangle
    work_area.update!(survey_data: right_triangle_survey_data)
    visit edit_work_area_path(work_area)
    wait_for_proposal
    expect(measured_by_pair).to eq('p-1|p-2' => 3, 'p-2|p-3' => 4, 'p-1|p-3' => 5)
  end

  let(:organization) { Organization.create!(name: '林業会社A') }

  let(:user) do
    User.create!(
      name: '山田太郎', email: 'map-test@example.com', role: :admin,
      password: 'password123', password_confirmation: 'password123',
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

  let(:work_area) { organization.work_areas.create!(name: '北側作業範囲', coordinates: coordinates) }

  before do
    driven_by :firefox_japan

    visit new_user_session_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'

    visit edit_work_area_path(work_area)
    wait_for_proposal
  end

  describe '外周点の操作' do
    it '地図の空白をクリックすると頂点が追加される' do
      expect(page).to have_css('#work-area-vertex-count', text: '頂点数：3点')

      click_map_at(34.3870, 132.4570)

      expect(page).to have_css('#work-area-vertex-count', text: '頂点数：4点')
    end

    it '既存の頂点をクリックすると選択状態になり、頂点数は増えない' do
      page.execute_script('document.querySelector(".outline-vertex").click()')

      expect(page).to have_css('.outline-vertex.is-selected')
      expect(page).to have_css('#work-area-vertex-count', text: '頂点数：3点')
    end

    it '別の頂点を選択すると前の選択が解除される' do
      page.execute_script('document.querySelectorAll(".outline-vertex")[0].click()')
      expect(page).to have_css('.outline-vertex.is-selected', count: 1)

      page.execute_script('document.querySelectorAll(".outline-vertex")[1].click()')
      expect(page).to have_css('.outline-vertex.is-selected', count: 1)
    end

    it 'Dキーを押すと選択中の頂点が削除される' do
      page.execute_script('document.querySelector(".outline-vertex").click()')
      page.find('body').send_keys('d')

      expect(page).to have_css('#work-area-vertex-count', text: '頂点数：2点')
      expect(page).to have_css('.outline-vertex', count: 2)
    end
  end

  describe '補助点モード' do
    before { click_button '補助点' }

    it '外周の内側をクリックすると補助点が追加され、外周点数は変わらない' do
      click_map_at(*centroid)

      expect(page).to have_css('.auxiliary-point', count: 1)
      expect(page).to have_css('#work-area-vertex-count', text: '頂点数：3点')
    end

    it '補助点をクリックすると選択され、Dキーで削除できる' do
      click_map_at(*centroid)
      page.execute_script('document.querySelector(".auxiliary-point").click()')
      expect(page).to have_css('.auxiliary-point.is-selected')

      page.find('body').send_keys('d')

      expect(page).to have_no_css('.auxiliary-point')
      expect(page).to have_css('.outline-vertex', count: 3)
    end

    it '外周の外側をクリックすると追加されずメッセージが表示される' do
      click_map_at(34.3900, 132.4600)

      expect(page).to have_no_css('.auxiliary-point')
      expect(page).to have_css('#work-area-message', text: '外周の内側に配置してください')
    end
  end

  describe '補助線モード' do
    it 'ボタンを押すとモードが切り替わる' do
      click_button '補助線'

      expect(page.find_by_id('auxiliary-line-mode-button')['aria-pressed']).to eq('true')
      expect(page.find_by_id('outline-mode-button')['aria-pressed']).to eq('false')
      expect(page).to have_css('#work-area-message', text: '補助線モード')
    end

    it '外周点と補助点を選ぶと作業者の線が作成され、保存用データに記録される' do
      click_button '補助点'
      click_map_at(*centroid)
      connect_line('.outline-vertex', '.auxiliary-point')

      expect(page).to have_css('.auxiliary-line', count: 1)
      expect(survey_data_field['lines']).to include(hash_including('origin' => 'worker'))
    end

    it '補助点を削除すると接続している線も削除される' do
      click_button '補助点'
      click_map_at(*centroid)
      connect_line('.outline-vertex', '.auxiliary-point')
      expect(page).to have_css('.auxiliary-line', count: 1)

      click_button '補助点'
      page.execute_script('document.querySelector(".auxiliary-point").click()')
      page.find('body').send_keys('d')

      expect(page).to have_no_css('.auxiliary-line')
      expect(survey_data_field['lines'].pluck('origin')).not_to include('worker')
    end
  end

  describe '保存時の検証' do
    it '補助点だけ追加して線で結ばない(孤立点)と保存されずメッセージが出る' do
      click_button '補助点'
      click_map_at(*centroid)

      click_button '変更を保存'

      expect(page).to have_current_path(edit_work_area_path(work_area))
      expect(page).to have_css('#work-area-message', text: /孤立|線/)
      expect(page).to have_css('.auxiliary-point.is-error')
    end

    it '四角形に対角線がない(三角形になっていない)と保存されない' do
      click_map_at(34.3870, 132.4570)
      page.execute_script('document.querySelector(".outline-vertex").click()')
      page.find('body').send_keys('d')
      click_map_at(34.3870, 132.4570)

      click_button '変更を保存'

      expect(page).to have_current_path(edit_work_area_path(work_area))
    end

    it '補助点と3本の線で3三角形に分割すると保存できる' do
      click_button '補助点'
      click_map_at(*centroid)
      3.times do |i|
        connect_line(".outline-vertex:nth-of-type(#{i + 1})", '.auxiliary-point')
      end

      click_button '変更を保存'

      expect(page).to have_current_path(work_area_path(work_area))
      saved = work_area.reload.survey_data
      expect(saved['points'].pluck('origin')).to include('worker')
      expect(saved['lines'].count { |l| l['origin'] == 'worker' }).to eq(3)
    end
  end

  describe '詳細画面(実測値の入力と地積)' do
    it '初期表示時に三角分割APIを呼び出さない' do
      work_area.update!(survey_data: centroid_survey_data)
      visit edit_work_area_path(work_area)
      expect(page).to have_css('#map')

      page.execute_script(<<~JAVASCRIPT)
        window.triangulationApiCalls = 0;
        const originalFetch = window.fetch.bind(window);
        window.fetch = (...args) => {
          if (args[0].toString().includes('/area/triangulate')) { window.triangulationApiCalls += 1; }
          return originalFetch(...args);
        };
        Turbo.visit(#{work_area_path(work_area).to_json});
      JAVASCRIPT

      expect(page).to have_css('#triangle-list .survey-triangle', count: 3)
      expect(page.evaluate_script('window.triangulationApiCalls')).to eq(0)
    end

    it '保存済みの線を詳細画面に表示する' do
      work_area.update!(survey_data: centroid_survey_data)

      visit work_area_path(work_area)

      expect(page).to have_css('.survey-line', count: 6)
      expect(page).to have_css('.auxiliary-line', count: 3)
    end

    it '実測値を入力すると地積(㎡)が計算される' do
      work_area.update!(survey_data: right_triangle_survey_data.tap do |data|
        data[:lines].each { |l| l[:measured_length] = nil }
      end)
      visit work_area_path(work_area)

      { 'l-1' => '3', 'l-2' => '4', 'l-3' => '5' }.each do |id, value|
        find(%(input[data-line-id="#{id}"])).set(value)
      end

      expect(page).to have_css('#survey-area-measured', text: '6')
      expect(page).to have_css('#survey-area-measured', text: '㎡')
    end

    it '保存済みの実測値から地積が表示される' do
      work_area.update!(survey_data: right_triangle_survey_data)

      visit work_area_path(work_area)

      expect(page).to have_css('#survey-area-measured', text: '6')
    end

    it '実測値を保存すると再表示しても残っている' do
      work_area.update!(survey_data: right_triangle_survey_data.tap do |data|
        data[:lines].each { |l| l[:measured_length] = nil }
      end)
      visit work_area_path(work_area)
      find(%(input[data-line-id="l-1"])).set('3.5')

      click_button '実測値を保存'
      expect(page).to have_css('#survey-save-message', text: /保存/)

      visit work_area_path(work_area)
      expect(find('input[data-line-id="l-1"]').value).to eq('3.5')
    end
  end

  describe '実測値の保持と消失の警告' do
    describe '線の再利用(carryOverMeasurements)' do
      def sample_points
        [
          { 'id' => 'p-1', 'lat' => 34.1, 'lng' => 132.1 },
          { 'id' => 'p-2', 'lat' => 34.2, 'lng' => 132.1 },
          { 'id' => 'p-3', 'lat' => 34.2, 'lng' => 132.2 }
        ]
      end

      def sample_old_lines
        [
          { 'id' => 'l-1', 'from' => 'p-1', 'to' => 'p-2', 'measured_length' => 3 },
          { 'id' => 'l-2', 'from' => 'p-2', 'to' => 'p-3', 'measured_length' => 4 }
        ]
      end

      it '端点の順序が逆でも、IDが変わっても、座標が同じ線は実測値を維持する' do
        new_lines = [
          { 'id' => 'l-9', 'from' => 'p-2', 'to' => 'p-1', 'measured_length' => nil },
          { 'id' => 'l-10', 'from' => 'p-3', 'to' => 'p-2', 'measured_length' => nil }
        ]

        result = carry_over(sample_old_lines, sample_points, new_lines, sample_points)

        expect(result['lines'].pluck('measured_length')).to eq([3, 4])
        expect(result['lostCount']).to eq(0)
      end

      it '端点の座標が変わった線は実測値を引き継がず、消える件数を返す' do
        moved = sample_points.map { |p| p['id'] == 'p-3' ? p.merge('lat' => 34.25) : p }
        new_lines = [
          { 'id' => 'l-9', 'from' => 'p-1', 'to' => 'p-2', 'measured_length' => nil },
          { 'id' => 'l-10', 'from' => 'p-2', 'to' => 'p-3', 'measured_length' => nil }
        ]

        result = carry_over(sample_old_lines, sample_points, new_lines, moved)

        expect(result['lines'].pluck('measured_length')).to eq([3, nil])
        expect(result['lostCount']).to eq(1)
      end

      it '線が無くなる場合は、実測済みの線の数がそのまま消える件数になる' do
        result = carry_over(sample_old_lines, sample_points, [], [])

        expect(result['lostCount']).to eq(2)
      end
    end

    describe '外周点を動かす' do
      it '実測済みの線がつながる点を動かすと確認が出て、OKならその線の実測値だけが消える' do
        open_edit_with_measured_triangle
        stub_confirm(true)

        drag_vertex(0, 34.3852, 132.4552) # p-1 : l-1(p-1,p-2) と l-3(p-3,p-1) の形が変わる
        wait_for_proposal

        expect(confirm_messages.size).to eq(1)
        expect(confirm_messages.first).to include('実測値が入力済みの線が2本')
        # 動かしていない p-2〜p-3 の線は、提案の線が作り直されても実測値を維持する
        expect(measured_by_pair).to eq('p-1|p-2' => nil, 'p-2|p-3' => 4, 'p-1|p-3' => nil)
      end

      it '確認でキャンセルすると、点の位置も実測値も元に戻る' do
        open_edit_with_measured_triangle
        stub_confirm(false)

        drag_vertex(0, 34.3852, 132.4552)

        expect(page).to have_css('#work-area-message', text: '操作を取り消しました')
        expect(confirm_messages.size).to eq(1)
        expect(measured_by_pair).to eq('p-1|p-2' => 3, 'p-2|p-3' => 4, 'p-1|p-3' => 5)
        expect(survey_data_field['points'].find { |p| p['id'] == 'p-1' }['lat']).to eq(34.3853)
      end

      it '位置が変わらなければ確認は出ず、実測値も消えない' do
        open_edit_with_measured_triangle
        stub_confirm(true)

        drag_vertex(0, 34.3853, 132.4553)

        expect(confirm_messages).to be_empty
        expect(measured_by_pair).to eq('p-1|p-2' => 3, 'p-2|p-3' => 4, 'p-1|p-3' => 5)
      end
    end

    describe '外周点を削除する' do
      it '実測済みの線がつながる点の削除は、確認でキャンセルすると何も変わらない' do
        open_edit_with_measured_triangle
        stub_confirm(false)

        page.execute_script('document.querySelector(".outline-vertex").click()')
        page.find('body').send_keys('d')

        expect(confirm_messages.first).to include('実測値が入力済みの線が2本')
        expect(page).to have_css('#work-area-vertex-count', text: '頂点数：3点')
        expect(measured_by_pair).to eq('p-1|p-2' => 3, 'p-2|p-3' => 4, 'p-1|p-3' => 5)
      end

      it 'OKで削除すると頂点が減り、形が変わる線の実測値は消える' do
        open_edit_with_measured_triangle
        stub_confirm(true)

        page.execute_script('document.querySelector(".outline-vertex").click()')
        page.find('body').send_keys('d')

        expect(page).to have_css('#work-area-vertex-count', text: '頂点数：2点')
        expect(confirm_messages).not_to be_empty
        expect(survey_data_field['lines']).to be_empty
      end
    end

    describe '線を削除する' do
      it '実測済みの作業者の線は、確認でキャンセルすると残る' do
        data = centroid_survey_data
        data[:lines][3][:measured_length] = 12.5
        work_area.update!(survey_data: data)
        visit edit_work_area_path(work_area)
        wait_for_proposal
        stub_confirm(false)

        page.execute_script(<<~JAVASCRIPT)
          document.querySelector(".auxiliary-line")
            .dispatchEvent(new MouseEvent("click", { bubbles: true }));
        JAVASCRIPT
        page.find('body').send_keys('d')

        expect(confirm_messages.first).to include('実測値が入力済みの線が1本')
        expect(survey_data_field['lines'].size).to eq(6)
      end
    end

    describe '実測値が無い場合' do
      it '確認を出さずに頂点を動かせる' do
        work_area.update!(survey_data: centroid_survey_data)
        visit edit_work_area_path(work_area)
        wait_for_proposal
        stub_confirm(true)

        drag_vertex(0, 34.3852, 132.4552)

        expect(confirm_messages).to be_empty
      end
    end
  end
end
