# frozen_string_literal: true

require 'rails_helper'

# 補助線を引いて線が交差するなど、全体の判定が失敗する状態でも、
# 外周の形と「外周の内側かどうか」の判定が崩れないことを確かめる。
#
# survey_model の関数はブラウザ内で呼ぶ（import map が効くページが必要なので、
# 計算ツールのトップを開く）。
RSpec.describe 'survey_model の外周の導出', type: :system do
  before { driven_by :firefox_japan }

  def outline_script
    <<~JAVASCRIPT
      window.outlineResult = null;
      window.outlineError = null;

      const script = document.createElement("script");
      script.type = "module";
      script.textContent = `
        import("survey_model")
          .then((model) => {
            const [points, lines, inside, outside] = ${arguments[0]};
            const analysis = model.analyze(points, lines);
            const outline = model.outlineOf(points, lines);
            const byId = new Map(points.map((p) => [p.id, p]));
            const ring = outline ? outline.map((id) => byId.get(id)) : null;

            window.outlineResult = {
              outline,
              plainOutline: analysis.outline,
              errorTypes: analysis.errors.map((e) => e.type),
              inside: ring ? model.pointInPolygon(inside, ring) : null,
              outside: ring ? model.pointInPolygon(outside, ring) : null
            };
          })
          .catch((error) => { window.outlineError = String(error); });
      `;
      document.head.appendChild(script);
    JAVASCRIPT
  end

  # 計算を簡単にするため、緯度経度は「基準点 + 0.001度の何個分」で組み立てる
  def geo(east, north)
    { lat: 34.380 + (north * 0.001), lng: 132.450 + (east * 0.001) }
  end

  def point(id, east, north, origin = 'input')
    geo(east, north).merge(id: id, origin: origin)
  end

  def line(id, from, to, origin)
    { id: id, from: from, to: to, origin: origin, estimated_length: 10, measured_length: nil }
  end

  # 凸の五角形 p-1〜p-5 を、p-1 から扇形に三角形へ分けた形
  # （自動の分割と同じ「proposed」の線）
  let(:points) do
    [point('p-1', 0, 2), point('p-2', 2, 3), point('p-3', 4, 2), point('p-4', 3, 0), point('p-5', 1, 0),
     point('p-6', 2.5, 1.4, 'worker')]
  end

  let(:outer_and_fan_lines) do
    [%w[l-1 p-1 p-2], %w[l-2 p-2 p-3], %w[l-3 p-3 p-4], %w[l-4 p-4 p-5], %w[l-5 p-5 p-1],
     %w[l-6 p-1 p-3], %w[l-7 p-1 p-4]].map { |id, from, to| line(id, from, to, 'proposed') }
  end

  # 補助点 p-6（三角形 p-1,p-3,p-4 の内側）から p-5 へ引く線は、
  # 線 p-1〜p-4 と交差する
  let(:crossing_aux_line) { line('l-8', 'p-6', 'p-5', 'worker') }

  let(:result) do
    visit root_path
    lines = outer_and_fan_lines + [crossing_aux_line]

    page.execute_script(outline_script, [points, lines, geo(2.0, 1.0), geo(5.0, 5.0)].to_json)
    wait_for_outline_result
  end

  def wait_for_outline_result
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop do
        error = page.evaluate_script('window.outlineError')
        raise "survey_model の読み込みに失敗: #{error}" if error

        found = page.evaluate_script('window.outlineResult')
        return found if found

        sleep 0.05
      end
    end
  end

  it '前提: 補助線が既存の線と交差すると、全体の判定は外周を返せない' do
    expect(result.values_at('plainOutline', 'errorTypes')).to eq([nil, ['crossing']])
  end

  it '補助線が交差していても、外周は元の五角形のまま（補助点は含まれない）' do
    expect(result['outline']).to match_array(%w[p-1 p-2 p-3 p-4 p-5])
  end

  it '補助線が交差していても、外周の内側は内側と判定される' do
    expect(result['inside']).to be(true)
  end

  it '補助線が交差していても、外周の外側は外側と判定される' do
    expect(result['outside']).to be(false)
  end
end
