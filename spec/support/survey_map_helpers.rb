# frozen_string_literal: true

# 作業範囲の地図操作 system spec 用のデータ生成・ブラウザ操作ヘルパー
module SurveyMapHelpers
  # 外周点(input)の3点。実測値の保護テストなどで共通に使う
  INPUT_POINTS = [
    ['p-1', 34.3853, 132.4553],
    ['p-2', 34.3860, 132.4560],
    ['p-3', 34.3865, 132.4550]
  ].freeze

  TRIANGLE_LINES = [%w[l-1 p-1 p-2], %w[l-2 p-2 p-3], %w[l-3 p-3 p-1]].freeze
  CENTROID_LINES = [%w[l-4 p-4 p-1], %w[l-5 p-4 p-2], %w[l-6 p-4 p-3]].freeze

  # 外周点(index番目)を実際のドラッグと同じイベント順で動かす
  DRAG_VERTEX_SCRIPT = <<~JAVASCRIPT
    const map = document.getElementById("map")._leaflet_map;
    const vertices = [];
    map.eachLayer((layer) => {
      if (layer instanceof L.Marker && layer.getElement()?.classList.contains("outline-vertex")) {
        vertices.push(layer);
      }
    });
    const marker = vertices[arguments[0]];
    marker.fire("dragstart");
    marker.setLatLng([arguments[1], arguments[2]]);
    marker.fire("drag");
    marker.fire("dragend");
  JAVASCRIPT

  # survey_model の純粋関数をブラウザ内で呼ぶ。
  # evaluate_async_script は隔離された実行環境で動き、ページの import map が効かないため、
  # ページ本体で動く module script を差し込んで実行し、結果を window 経由で受け取る。
  CARRY_OVER_SCRIPT = <<~JAVASCRIPT
    window.carryOverResult = null;
    window.carryOverError = null;

    const script = document.createElement("script");
    script.type = "module";
    script.textContent = `
      import("survey_model")
        .then((model) => {
          const [a, b, c, d] = ${arguments[0]};
          window.carryOverResult = model.carryOverMeasurements(a, b, c, d);
        })
        .catch((error) => { window.carryOverError = String(error); });
    `;
    document.head.appendChild(script);
  JAVASCRIPT

  def survey_point(id, lat, lng, origin = 'input')
    { id: id, lat: lat, lng: lng, origin: origin }
  end

  def survey_line(id, from, to, origin, measured = nil)
    { id: id, from: from, to: to, origin: origin, estimated_length: 10, measured_length: measured }
  end

  def input_points
    INPUT_POINTS.map { |id, lat, lng| survey_point(id, lat, lng) }
  end

  def triangle_lines(measured = [nil, nil, nil])
    TRIANGLE_LINES.zip(measured).map { |(id, from, to), value| survey_line(id, from, to, 'proposed', value) }
  end

  # 3点の外周に重心(補助点)と3本の線を足した「3三角形」の保存データ
  def centroid_survey_data
    {
      version: 2,
      points: input_points + [survey_point('p-4', 34.38593, 132.45543, 'worker')],
      lines: triangle_lines + CENTROID_LINES.map { |id, from, to| survey_line(id, from, to, 'worker') }
    }
  end

  # 3-4-5 の直角三角形(実測値で面積 6 ㎡)
  def right_triangle_survey_data
    { version: 2, points: input_points, lines: triangle_lines([3, 4, 5]) }
  end

  def drag_vertex(index, lat, lng)
    page.execute_script(DRAG_VERTEX_SCRIPT, index, lat, lng)
  end

  def carry_over(*arguments)
    page.execute_script(CARRY_OVER_SCRIPT, arguments.to_json)

    wait_for_carry_over_result
  end

  def wait_for_carry_over_result
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop do
        error = page.evaluate_script('window.carryOverError')
        raise "survey_model の読み込みに失敗: #{error}" if error

        result = page.evaluate_script('window.carryOverResult')
        return result if result

        sleep 0.05
      end
    end
  end
end
