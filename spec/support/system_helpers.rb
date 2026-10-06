# frozen_string_literal: true

module SystemHelpers
  def set_viewport(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end

  def expect_no_horizontal_scroll
    expect(
      page.evaluate_script(
        'document.documentElement.scrollWidth <= document.documentElement.clientWidth'
      )
    ).to be(true)
  end
end
