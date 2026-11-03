# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::EstimatesHelper, type: :helper do
  describe '#area_source_text' do
    def imported_estimate(estimated:, work_area:)
      Estimate.new.tap do |estimate|
        allow(estimate).to receive_messages(
          area_from_map: true, area_source_kind_estimated?: estimated, work_area: work_area
        )
      end
    end

    it '取り込み元の作業範囲が削除されているとき、そのことを説明に含める（概算）' do
      text = helper.area_source_text(imported_estimate(estimated: true, work_area: nil))

      expect(text).to eq('作業範囲の概算地積（現場で測る前の、地図上の概算）から取り込んだ値（作業範囲は削除されています）')
    end

    it '取り込み元の作業範囲が削除されているとき、そのことを説明に含める（実測）' do
      text = helper.area_source_text(imported_estimate(estimated: false, work_area: nil))

      expect(text).to eq('作業範囲の実測地積から取り込んだ値（作業範囲は削除されています）')
    end

    it '地図から取り込んでいない見積は、説明を出さない' do
      expect(helper.area_source_text(Estimate.new)).to be_nil
    end
  end
end
