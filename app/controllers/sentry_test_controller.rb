# frozen_string_literal: true

class SentryTestController < ApplicationController
  def show
    raise 'Sentry test error'
  end
end
