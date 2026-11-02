# frozen_string_literal: true

require 'rails_helper'

# 見積の面積は㎡で保存する。手入力が正で、作業範囲の実測地積は取り込める参考値。
RSpec.describe Estimate do
  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:other_organization) { Organization.create!(name: '林業会社B') }
  let(:estimate) { described_class.build_for(organization, name: '現場A').tap(&:save!) }

  def create_work_area(owner, name: '北側')
    owner.work_areas.create!(name: name, coordinates: [[35.0, 139.0], [35.0, 139.001], [35.001, 139.0]])
  end

  describe '#assign_area' do
    it 'haで受け取った面積を、㎡にして入れる' do
      estimate.assign_area('0.842', 'ha')

      expect(estimate.area).to eq(8420)
    end

    it '㎡や単位なしなら、そのまま入れる' do
      estimate.assign_area('8420', 'm2')
      expect(estimate.area).to eq(8420)

      estimate.assign_area('100', nil)
      expect(estimate.area).to eq(100)
    end

    it '全角数字やカンマも受け付ける' do
      estimate.assign_area('１，２．５', 'ha')

      expect(estimate.area).to eq(125_000)
    end

    it '知らない単位は保存できない。空の単位は㎡' do
      estimate.assign_area('100', 'km2')
      expect(estimate).not_to be_valid
      expect(estimate.errors.full_messages).to include('面積の単位が正しくありません')

      estimate.assign_area('100', '')
      expect(estimate).to be_valid
    end

    it '空なら、単位に関係なく空にする' do
      estimate.assign_area('', 'ha')

      expect(estimate.area).to be_nil
    end

    it '㎡の小数2桁に丸めて保存する' do
      estimate.assign_area('0.000012345', 'ha')

      expect(estimate.area).to eq(BigDecimal('0.12'))
    end
  end

  describe '#import_area' do
    it '作業範囲と面積を保存し、取り込んだ値として扱う' do
      work_area = create_work_area(organization)

      expect(estimate.import_area(work_area, '8420.5')).to be true

      expect(estimate.reload).to have_attributes(area: BigDecimal('8420.5'), work_area: work_area, area_from_map: true)
    end

    it '概算面積として取り込める。種類を省くと実測' do
      work_area = create_work_area(organization)

      estimate.import_area(work_area, 8000, :estimated)
      expect(estimate.reload.area_source_kind).to eq('estimated')

      estimate.import_area(work_area, 8420)
      expect(estimate.reload.area_source_kind).to eq('measured')
    end

    it '不正な種類は取り込まない' do
      expect(estimate.import_area(create_work_area(organization), 8420, :unknown)).to be false
      expect(estimate.reload).to have_attributes(area: nil, area_source_kind: nil)
    end

    it '手で面積を変えると、取り込んだ値ではなくなる。作業範囲の控えは残る' do
      work_area = create_work_area(organization)
      estimate.import_area(work_area, 8420)

      estimate.assign_area('9000', 'm2')
      estimate.save!

      expect(estimate.reload).to have_attributes(
        area: 9000, area_from_map: false, area_source_kind: nil, work_area: work_area
      )
    end

    it '面積を変えずに名前だけ変えても、取り込んだ値のまま' do
      estimate.import_area(create_work_area(organization), 8420)

      estimate.update!(name: '名前だけ変更')

      expect(estimate.reload.area_from_map).to be true
    end

    it '続けて取り込み直しても、取り込んだ値のまま' do
      work_area = create_work_area(organization)
      estimate.import_area(work_area, 8420)

      estimate.import_area(work_area, 9000)

      expect(estimate.reload).to have_attributes(area: 9000, area_from_map: true)
    end

    it '面積が空・0以下なら取り込まず、falseを返す' do
      work_area = create_work_area(organization)

      expect(estimate.import_area(work_area, '')).to be false
      expect(estimate.errors).to be_added(:area, :blank)
      expect(estimate.import_area(work_area, '0')).to be false
      expect(estimate.reload).to have_attributes(area: nil, work_area: nil, area_from_map: false)
    end

    it '他社の作業範囲は取り込めない' do
      other_work_area = create_work_area(other_organization)

      expect(estimate.import_area(other_work_area, 8420)).to be false
      expect(estimate.errors).to be_added(:work_area, :invalid)
    end

    it '作業範囲が消えても、見積と面積は残る' do
      work_area = create_work_area(organization)
      estimate.import_area(work_area, '8420.5')

      work_area.destroy!

      expect(estimate.reload).to have_attributes(work_area: nil, area: BigDecimal('8420.5'), area_from_map: true)
    end
  end
end
