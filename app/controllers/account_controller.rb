# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

class AccountController < ApplicationController
  helper :custom_fields
  include CustomFieldsHelper

  self.main_menu = false

  # prevents login action to be filtered by check_if_login_required application scope filter
  skip_before_action :check_if_login_required, :check_password_change

  # Overrides ApplicationController#verify_authenticity_token to disable
  # token verification on openid callbacks
  def verify_authenticity_token
    unless using_open_id?
      super
    end
  end

  # Login request and validation
  def login
    if request.post?
      authenticate_user
    else
      if User.current.logged?
        redirect_back_or_default home_url, :referer => true
      end
    end
  rescue AuthSourceException => e
    logger.error "An error occurred when authenticating #{params[:username]}: #{e.message}"
    render_error :message => e.message
  end

  # Log out current user and redirect to welcome page
  def logout
    if User.current.anonymous?
      redirect_to home_url
    elsif request.post?
      logout_user
      redirect_to home_url
    end
    # display the logout form
  end

  # Lets user choose a new password
  def lost_password
    (redirect_to(home_url); return) unless Setting.lost_password?
    if prt = (params[:token] || session[:password_recovery_token])
      @token = Token.find_token("recovery", prt.to_s)
      if @token.nil?
        redirect_to home_url
        return
      elsif @token.expired?
        # remove expired token from session and let user try again
        session[:password_recovery_token] = nil
        flash[:error] = l(:error_token_expired)
        redirect_to lost_password_url
        return
      end

      # redirect to remove the token query parameter from the URL and add it to the session
      if request.query_parameters[:token].present?
        session[:password_recovery_token] = @token.value
        redirect_to lost_password_url
        return
      end

      @user = @token.user
      unless @user && @user.active?
        redirect_to home_url
        return
      end
      if request.post?
        if @user.must_change_passwd? && @user.check_password?(params[:new_password])
          flash.now[:error] = l(:notice_new_password_must_be_different)
        else
          @user.password, @user.password_confirmation = params[:new_password], params[:new_password_confirmation]
          @user.must_change_passwd = false
          if @user.save
            @token.destroy
            Mailer.deliver_password_updated(@user, User.current)
            flash[:notice] = l(:notice_account_password_updated)
            redirect_to signin_path
            return
          end
        end
      end
      render :template => "account/password_recovery"
      return
    else
      if request.post?
        email = params[:mail].to_s.strip
        user = User.find_by_mail(email)
        # user not found
        unless user
          flash.now[:error] = l(:notice_account_unknown_email)
          return
        end
        unless user.active?
          handle_inactive_user(user, lost_password_path)
          return
        end
        # user cannot change its password
        unless user.change_password_allowed?
          flash.now[:error] = l(:notice_can_t_change_password)
          return
        end
        # create a new token for password recovery
        token = Token.new(:user => user, :action => "recovery")
        if token.save
          # Don't use the param to send the email
          recipent = user.mails.detect {|e| email.casecmp(e) == 0} || user.mail
          Mailer.deliver_lost_password(user, token, recipent)
          flash[:notice] = l(:notice_account_lost_email_sent)
          redirect_to signin_path
          return
        end
      end
    end
  end

  # User self-registration
  def register
    (redirect_to(home_url); return) unless Setting.self_registration? || session[:auth_source_registration]
    if !request.post?
      session[:auth_source_registration] = nil
      @user = User.new(:language => current_language.to_s)
    else
      user_params = params[:user] || {}
      @user = User.new
      @user.safe_attributes = user_params
      @user.pref.safe_attributes = params[:pref]
      @user.admin = false
      @user.register
      if session[:auth_source_registration]
        @user.activate
        @user.login = session[:auth_source_registration][:login]
        @user.auth_source_id = session[:auth_source_registration][:auth_source_id]
        if @user.save
          session[:auth_source_registration] = nil
          self.logged_user = @user
          flash[:notice] = l(:notice_account_activated)
          redirect_to my_account_path
        end
      else
        unless user_params[:identity_url].present? && user_params[:password].blank? && user_params[:password_confirmation].blank?
          @user.password, @user.password_confirmation = user_params[:password], user_params[:password_confirmation]
        end

        case Setting.self_registration
        when '1'
          register_by_email_activation(@user)
        when '3'
          register_automatically(@user)
        else
          register_manually_by_administrator(@user)
        end
      end
    end
  end

  # Token based account activation
  def activate
    (redirect_to(home_url); return) unless Setting.self_registration? && params[:token].present?
    token = Token.find_token('register', params[:token].to_s)
    (redirect_to(home_url); return) unless token and !token.expired?
    user = token.user
    (redirect_to(home_url); return) unless user.registered?
    user.activate
    if user.save
      token.destroy
      flash[:notice] = l(:notice_account_activated)
    end
    redirect_to signin_path
  end

  # Sends a new account activation email
  def activation_email
    if session[:registered_user_id] && Setting.self_registration == '1'
      user_id = session.delete(:registered_user_id).to_i
      user = User.find_by_id(user_id)
      if user && user.registered?
        register_by_email_activation(user)
        return
      end
    end
    redirect_to(home_url)
  end

  private

  def authenticate_user
    if Setting.openid? && using_open_id?
      open_id_authenticate(params[:openid_url])
    else
      password_authentication
    end
  end

  def password_authentication
    user = User.try_to_login(params[:username], params[:password], false)

    if user.nil?
      invalid_credentials
    elsif user.new_record?
      onthefly_creation_failed(user, {:login => user.login, :auth_source_id => user.auth_source_id })
    else
      # Valid user
      if user.active?
        successful_authentication(user)
        update_sudo_timestamp! # activate Sudo Mode
      else
        handle_inactive_user(user)
      end
    end
  end

  def open_id_authenticate(openid_url)
    back_url = signin_url(:autologin => params[:autologin])
    authenticate_with_open_id(
          openid_url, :required => [:nickname, :fullname, :email],
          :return_to => back_url, :method => :post
    ) do |result, identity_url, registration|
      if result.successful?
        user = User.find_or_initialize_by_identity_url(identity_url)
        if user.new_record?
          # Self-registration off
          (redirect_to(home_url); return) unless Setting.self_registration?
          # Create on the fly
          user.login = registration['nickname'] unless registration['nickname'].nil?
          user.mail = registration['email'] unless registration['email'].nil?
          user.firstname, user.lastname = registration['fullname'].split(' ') unless registration['fullname'].nil?
          user.random_password
          user.register
          case Setting.self_registration
          when '1'
            register_by_email_activation(user) do
              onthefly_creation_failed(user)
            end
          when '3'
            register_automatically(user) do
              onthefly_creation_failed(user)
            end
          else
            register_manually_by_administrator(user) do
              onthefly_creation_failed(user)
            end
          end
        else
          # Existing record
          if user.active?
            successful_authentication(user)
          else
            handle_inactive_user(user)
          end
        end
      end
    end
  end

  def successful_authentication(user)
    logger.info "Successful authentication for '#{user.login}' from #{request.remote_ip} at #{Time.now.utc}"
    # Valid user
    self.logged_user = user
    # generate a key and set cookie if autologin
    if params[:autologin] && Setting.autologin?
      set_autologin_cookie(user)
    end
    call_hook(:controller_account_success_authentication_after, {:user => user })
    redirect_back_or_default my_page_path
  end

  def set_autologin_cookie(user)
    token = user.generate_autologin_token
    secure = Redmine::Configuration['autologin_cookie_secure']
    if secure.nil?
      secure = request.ssl?
    end
    cookie_options = {
      :value => token,
      :expires => 1.year.from_now,
      :path => (Redmine::Configuration['autologin_cookie_path'] || RedmineApp::Application.config.relative_url_root || '/'),
      :secure => secure,
      :httponly => true
    }
    cookies[autologin_cookie_name] = cookie_options
  end

  # Onthefly creation failed, display the registration form to fill/fix attributes
  def onthefly_creation_failed(user, auth_source_options = { })
    @user = user
    session[:auth_source_registration] = auth_source_options unless auth_source_options.empty?
    render :action => 'register'
  end

  def invalid_credentials
    logger.warn "Failed login for '#{params[:username]}' from #{request.remote_ip} at #{Time.now.utc}"
    flash.now[:error] = l(:notice_account_invalid_credentials)
  end

  # Register a user for email activation.
  #
  # Pass a block for behavior when a user fails to save
  def register_by_email_activation(user, &block)
    token = Token.new(:user => user, :action => "register")
    if user.save and token.save
      Mailer.deliver_register(user, token)
      flash[:notice] = l(:notice_account_register_done, :email => ERB::Util.h(user.mail))
      redirect_to signin_path
    else
      yield if block_given?
    end
  end

  # Automatically register a user
  #
  # Pass a block for behavior when a user fails to save
  def register_automatically(user, &block)
    # Automatic activation
    user.activate
    user.last_login_on = Time.now
    if user.save
      self.logged_user = user
      flash[:notice] = l(:notice_account_activated)
      redirect_to my_account_path
    else
      yield if block_given?
    end
  end

  # Manual activation by the administrator
  #
  # Pass a block for behavior when a user fails to save
  def register_manually_by_administrator(user, &block)
    if user.save
      # Sends an email to the administrators
      Mailer.deliver_account_activation_request(user)
      account_pending(user)
    else
      yield if block_given?
    end
  end

  def handle_inactive_user(user, redirect_path=signin_path)
    if user.registered?
      account_pending(user, redirect_path)
    else
      account_locked(user, redirect_path)
    end
  end

  def account_pending(user, redirect_path=signin_path)
    if Setting.self_registration == '1'
      flash[:error] = l(:notice_account_not_activated_yet, :url => activation_email_path)
      session[:registered_user_id] = user.id
    else
      flash[:error] = l(:notice_account_pending)
    end
    redirect_to redirect_path
  end

  def account_locked(user, redirect_path=signin_path)
    flash[:error] = l(:notice_account_locked)
    redirect_to redirect_path
  end
end
