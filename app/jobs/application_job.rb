# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  include Redmine::JobWrapper

  around_enqueue :keep_current_user
end
