# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubmissionBuilder do
  include EstimateSampleHelpers

  let(:organization) { Organization.create!(name: '林業会社A') }
  let(:estimate) { create_sample_estimate(organization).tap { |sample| sample.update!(client_name: '山田建設') } }

  def build(**attributes)
    estimate.update!(attributes) if attributes.any?
    described_class.call(estimate.reload)
  end

  describe '項目別の内訳（標準）' do
    it '見積番号・現場名・宛名・金額（税抜 / 消費税 / 税込）を持つ' do
      expect(build).to have_attributes(
        number_label: '見積-0001', site_name: '北側作業範囲', client_name: '山田建設', format: :breakdown,
        price: 929_000, tax_rate: 10, tax: 92_900, total: 1_021_900, problem: nil, area_price: nil
      )
    end

    it '区分の並び順で、直接費の割合に応じて金額を配る' do
      rows = build.rows.map { |row| [row.name, row.amount] }

      expect(rows).to eq([['伐採費', 252_000], ['整理費', 144_000], ['機械費', 270_000], ['処分費', 263_000]])
    end

    it '内訳の合計は、金額（税抜）と必ず一致する' do
      submission = build

      expect(submission.rows.sum(&:amount)).to eq(submission.price)
    end

    it '配った金額が0円になる区分は載せないが、合計は合う' do
      tiny = organization.cost_categories.create!(name: '少額')
      estimate.estimate_lines.each(&:destroy!)
      add_line(estimate, organization.cost_categories.find_or_create_by!(name: '伐採費'), 600_000)
      add_line(estimate, tiny, 1)

      submission = build

      expect(submission.rows.map(&:name)).to eq(['伐採費'])
      expect(submission.rows.sum(&:amount)).to eq(submission.price)
    end

    it '数量・単位・単価は持たない（内訳の金額だけ）' do
      expect(build.rows).to all(have_attributes(quantity: nil, unit: nil, unit_price: nil))
    end
  end

  describe '㎡単価' do
    it '金額 ÷ 面積を丸めた単価と、単価 × 面積との差を持つ。金額は変わらない' do
      submission = build(submission_format: :area_price)

      expect(submission).to have_attributes(format: :area_price, price: 929_000, total: 1_021_900, problem: nil)
      expect(submission.area_price).to have_attributes(unit_price: 111, product: 934_620, difference: -5_620)
      expect(submission.rows.size).to eq(1)
      expect(submission.rows.first).to have_attributes(
        name: '作業費', quantity: 8420, unit: '㎡', unit_price: 111, amount: 929_000
      )
    end

    it '見積にコピーされた㎡単価の端数の単位を使う（設定をあとで変えても変わらない）' do
      EstimateSetting.for(organization).update!(area_price_rounding_unit: '0.1')
      sample = create_sample_estimate(organization, name: '南側作業範囲')
      sample.update!(submission_format: :area_price)
      EstimateSetting.for(organization).update!(area_price_rounding_unit: 10)

      expect(described_class.call(sample.reload).area_price)
        .to have_attributes(unit_price: BigDecimal('110.4'), product: 929_568, difference: -568)
    end
  end

  describe '提出書を作れないとき' do
    it '面積が入っていない㎡単価は、理由を返し、行は空' do
      submission = build(submission_format: :area_price, area: nil)

      expect(submission.problem).to eq(described_class::NO_AREA_MESSAGE)
      expect(submission).to have_attributes(rows: [], area_price: nil)
    end

    it '面積が入っていなくても、項目別の内訳なら作れる' do
      expect(build(area: nil)).to have_attributes(problem: nil)
    end

    it '明細がない見積は、理由を返し、行は空' do
      empty = Estimate.build_for(organization, name: '現場B').tap(&:save!)

      expect(described_class.call(empty)).to have_attributes(problem: described_class::NO_LINES_MESSAGE, rows: [])
    end
  end

  describe '自社の情報' do
    it '設定がなければ、組織の名前を社名にする' do
      expect(build.issuer).to have_attributes(name: '林業会社A', address: nil, phone: nil)
    end

    it '設定した社名・住所・電話番号・備考を持つ' do
      EstimateSetting.for(organization).update!(
        issuer_name: '株式会社A林業', issuer_address: '長野県1-2-3', issuer_phone: '026-000-0000',
        submission_note: '有効期限は1か月です'
      )

      submission = build

      expect(submission.issuer).to have_attributes(name: '株式会社A林業', address: '長野県1-2-3', phone: '026-000-0000')
      expect(submission.note).to eq('有効期限は1か月です')
    end
  end

  it '原価・利益率・利益は、提出する内容に含まれない' do
    names = Submission.members.map(&:to_s) + Submission::Row.members.map(&:to_s)

    expect(names.grep(/cost|margin|profit|overhead|direct/)).to be_empty
  end

  def add_line(estimate, category, unit_price)
    estimate.estimate_lines.create!(
      cost_category: category, name: '作業', unit: '式', quantity: 1, unit_price: unit_price
    )
  end
end
