# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvitationLink do
  let(:token) { 'abc123' }
  let(:expected_path) { '/users/password/edit?reset_password_token=abc123' }

  it '基本URLとトークンから、パスワード設定のURLを作る' do
    expect(described_class.url(token, 'https://example.com')).to eq("https://example.com#{expected_path}")
  end

  it '基本URLの末尾にスラッシュがあっても、二重にならない' do
    expect(described_class.url(token, 'https://example.com/')).to eq("https://example.com#{expected_path}")
  end

  it '基本URLがないときは、パスだけを返す' do
    expect(described_class.url(token, nil)).to eq(expected_path)
  end
end
