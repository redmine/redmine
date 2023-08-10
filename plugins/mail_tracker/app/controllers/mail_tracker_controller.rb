class MailTrackerController < ApplicationController
  unloadable
  def index
    @rules = MailTrackingRule.all
    @mail_source = MailSource.last
    # @users = User.all
  end

  def show
  end


  def update
  end
end