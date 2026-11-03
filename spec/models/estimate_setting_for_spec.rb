# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EstimateSetting, '.for' do
  let(:organization) { Organization.create!(name: '林業会社A') }

  it '同時に別のリクエストが先に作っていたときは、作られた設定を返す' do
    existing = described_class.for(organization)
    allow(described_class).to receive(:find_or_create_by!).and_raise(ActiveRecord::RecordNotUnique)

    expect(described_class.for(organization)).to eq(existing)
  end
end
