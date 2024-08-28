class MailSourceBlacklistsController < ApplicationController
  unloadable
  def create
    @mail_source_blacklist = MailSourceBlacklist.new(mail_source_blacklist_params)
    @mail_source_blacklist.user = User.current
    if @mail_source_blacklist.save
      render 'create'
    else
      @error = 'Could not blacklist the email'
      render 'error'
    end
  end

  def destroy
    @mail_source_blacklist = MailSourceBlacklist.find(params[:id])
    if @mail_source_blacklist.destroy
      render 'create'
    else 
      @error = 'Could not delete the blacklisted email'
      render 'error'
    end      
  end

  private

  def mail_source_blacklist_params
    params.require(:mail_source_blacklist).permit(:email)
  end
end