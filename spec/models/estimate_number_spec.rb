# frozen_string_literal: true

require 'rails_helper'

# 見積番号（会社ごとの連番）・宛名・消費税・検索。
RSpec.describe Estimate do
  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:other_organization) { Organization.create!(name: '林業会社B') }

  def create_estimate(owner, name = '現場A', **attributes)
    described_class.build_for(owner, { name: name }.merge(attributes)).tap(&:save!)
  end

  describe '見積番号' do
    it '会社ごとに1から、順に付く。他社とは独立している' do
      expect(create_estimate(organization).number).to eq(1)
      expect(create_estimate(organization).number).to eq(2)
      expect(create_estimate(other_organization).number).to eq(1)
    end

    it '見積を削除しても、番号は使い回さない' do
      create_estimate(organization)
      last = create_estimate(organization)

      last.destroy!

      expect(create_estimate(organization).number).to eq(3)
    end

    it '保存しない（検証だけの）見積は、番号を消費しない' do
      described_class.build_for(organization, name: '現場A').valid?

      expect(create_estimate(organization).number).to eq(1)
    end

    it '番号は、頭の文字と4桁で表示する。頭の文字は、作成時点のものを持つ' do
      EstimateSetting.for(organization).update!(number_prefix: 'No.')
      old = create_estimate(organization)

      EstimateSetting.for(organization).update!(number_prefix: 'EST-')

      expect(old.reload.number_label).to eq('No.0001')
      expect(create_estimate(organization).number_label).to eq('EST-0002')
    end

    it '会社内で、同じ番号は保存できない（DBの一意制約）。他社なら同じ番号でよい' do
      create_estimate(organization)
      duplicate = described_class.build_for(organization, name: '現場B').tap { |estimate| estimate.number = 1 }

      expect { duplicate.save! }.to raise_error(ActiveRecord::RecordNotUnique)
      expect(create_estimate(other_organization).number).to eq(1)
    end

    it '番号がまだ無い見積は、表示が空' do
      expect(described_class.new.number_label).to be_nil
    end
  end

  describe '消費税' do
    it '見積の設定の税率と端数の処理を、作成時点でコピーする。あとで設定を変えても変わらない' do
      EstimateSetting.for(organization).update!(tax_rate: 8, tax_rounding_mode: :ceil)
      estimate = create_estimate(organization)

      EstimateSetting.for(organization).update!(tax_rate: 10, tax_rounding_mode: :floor)

      expect(estimate.reload).to have_attributes(tax_rate: 8, tax_rounding_mode: 'ceil')
      expect(estimate.tax_for(1_001)).to eq(81)
    end

    it '初期値は、税率10%・切り捨て' do
      expect(create_estimate(organization)).to have_attributes(tax_rate: 10, tax_rounding_mode: 'floor')
    end

    it '税率は0〜100%' do
      estimate = described_class.build_for(organization, name: '現場A')

      expect(estimate).to be_valid
      estimate.tax_rate = -1
      expect(estimate).not_to be_valid
      estimate.tax_rate = 101
      expect(estimate).not_to be_valid
    end
  end

  describe '宛名' do
    it '空でもよく、100文字まで' do
      expect(described_class.build_for(organization, name: '現場A', client_name: nil)).to be_valid
      expect(described_class.build_for(organization, name: '現場A', client_name: 'あ' * 100)).to be_valid
      expect(described_class.build_for(organization, name: '現場A', client_name: 'あ' * 101)).not_to be_valid
    end
  end

  describe '.search' do
    before do
      create_estimate(organization, '北側の伐採', client_name: '山田建設')
      create_estimate(organization, '南側の整理', client_name: '田中林業')
      create_estimate(other_organization, '北側の他社分')
    end

    def names(query)
      organization.estimates.search(query).pluck(:name)
    end

    it '空なら、すべて' do
      expect(names('')).to contain_exactly('北側の伐採', '南側の整理')
      expect(names(nil)).to contain_exactly('北側の伐採', '南側の整理')
    end

    it '現場名・宛名で探せる' do
      expect(names('北側')).to eq(['北側の伐採'])
      expect(names('田中')).to eq(['南側の整理'])
    end

    it '番号でも探せる（数字だけ、または頭の文字つき）' do
      expect(names('2')).to eq(['南側の整理'])
      expect(names('見積-0001')).to eq(['北側の伐採'])
    end

    it '%や_を含む文字列は、そのまま探す' do
      expect(names('%')).to be_empty
      expect(names('_')).to be_empty
    end

    it '他社の見積は出ない' do
      expect(names('他社')).to be_empty
    end
  end
end
