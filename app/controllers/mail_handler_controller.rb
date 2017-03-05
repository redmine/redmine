# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class MailHandlerController < ActionController::Base
  include Redmine::Hook::Helper
  before_action :check_credential

  # Displays the email submission form
  def new
  end

  # Submits an incoming email to MailHandler
  def index
    options = params.dup
    email = options.delete(:email)
    if object = MailHandler.receive(email, options)
      call_issues_hook(object)
      head :created
    else
      head :unprocessable_entity
    end
  end

  private

  def check_credential
    User.current = nil
    unless Setting.mail_handler_api_enabled? && params[:key].to_s == Setting.mail_handler_api_key
      render :plain => 'Access denied. Incoming emails WS is disabled or key is invalid.', :status => 403
    end
  end

  def call_issues_hook(object)
    case object
    when Issue
      call_hook(:controller_issues_new_after_save, { :params => params, :issue => object })
    when Journal
      call_hook(:controller_issues_edit_after_save, { :params => params, :issue => object.issue, :journal => object })
    end
  end
end
