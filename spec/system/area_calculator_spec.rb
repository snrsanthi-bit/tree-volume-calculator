require "rails_helper"
RSpec.describe "地積計算", type: :system do
  before do
    driven_by :selenium_firefox
  end
  describe "三角形1つの場合" do
    it "正しい面積が表示される" do
      visit root_path

      fill_in "辺 A (m)", with: 3
      fill_in "辺 B (m)", with: 4
      fill_in "辺 C (m)", with: 5

      click_button "面積を計算する"

      expect(page).to have_content("6.0")
      expect(page).to have_content("0.0006")
    end
  end
  describe "三角形複数の場合" do
    it "正しい面積が表示される" do
      visit root_path

      within all(".triangle").first do
        fill_in "辺 A (m)", with: 3
        fill_in "辺 B (m)", with: 4
        fill_in "辺 C (m)", with: 5
      end

      click_button "三角形を追加"

       expect(page).to have_css(".triangle", count: 2)

        within all(".triangle").last do
          fill_in "辺 A (m)", with: 3
          fill_in "辺 B (m)", with: 4
          fill_in "辺 C (m)", with: 5
        end

        click_button "面積を計算する"

        expect(page).to have_content("12.0")
        expect(page).to have_content("0.0012")
    end
  end
end
