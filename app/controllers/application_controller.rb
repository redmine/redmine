# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
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

require 'uri'
require 'cgi'

class Unauthorized < StandardError; end

class ApplicationController < ActionController::Base
  include Redmine::I18n
  include Redmine::Pagination
  include Redmine::Hook::Helper
  include RoutesHelper
  include AvatarsHelper

  helper :routes
  helper :avatars

  class_attribute :accept_api_auth_actions
  class_attribute :accept_atom_auth_actions
  class_attribute :model_object

  layout 'base'

  def verify_authenticity_token
    unless api_request?
      super
    end
  end

  def handle_unverified_request
    unless api_request?
      begin
        super
      rescue ActionController::InvalidAuthenticityToken => e
        logger.error("ActionController::InvalidAuthenticityToken: #{e.message}") if logger
      ensure
        cookies.delete(autologin_cookie_name)
        self.logged_user = nil
        set_localization
        render_error :status => 422, :message => l(:error_invalid_authenticity_token)
      end
    end
  end

  before_action :session_expiration, :user_setup, :check_if_login_required, :set_localization, :check_password_change, :check_twofa_activation
  after_action :record_project_usage

  rescue_from ::Unauthorized, :with => :deny_access
  rescue_from ::ActionView::MissingTemplate, :with => :missing_template

  include Redmine::Search::Controller
  include Redmine::MenuManager::MenuController
  helper Redmine::MenuManager::MenuHelper

  include Redmine::SudoMode::Controller

  def session_expiration
    if session[:user_id] && Rails.application.config.redmine_verify_sessions != false
      if session_expired? && !try_to_autologin
        set_localization(User.active.find_by_id(session[:user_id]))
        self.logged_user = nil
        flash[:error] = l(:error_session_expired)
        require_login
      end
    end
  end

  def session_expired?
    ! User.verify_session_token(session[:user_id], session[:tk])
  end

  def start_user_session(user)
    session[:user_id] = user.id
    session[:tk] = user.generate_session_token
    if user.must_change_password?
      session[:pwd] = '1'
    end
    if user.must_activate_twofa?
      session[:must_activate_twofa] = '1'
    end
  end

  def user_setup
    # Check the settings cache for each request
    Setting.check_cache
    # Find the current user
    User.current = find_current_user
    logger.info("  Current user: " + (User.current.logged? ? "#{User.current.login} (id=#{User.current.id})" : "anonymous")) if logger
  end

  # Returns the current user or nil if no user is logged in
  # and starts a session if needed
  def find_current_user
    user = nil
    unless api_request?
      if session[:user_id]
        # existing session
        user =
          begin
            User.active.find(session[:user_id])
          rescue
            nil
          end
      elsif autologin_user = try_to_autologin
        user = autologin_user
      elsif params[:format] == 'atom' && params[:key] && request.get? && accept_atom_auth?
        # ATOM key authentication does not start a session
        user = User.find_by_atom_key(params[:key])
      end
    end
    if user.nil? && Setting.rest_api_enabled? && accept_api_auth?
      if (key = api_key_from_request)
        # Use API key
        user = User.find_by_api_key(key)
      elsif /\ABasic /i.match?(request.authorization.to_s)
        # HTTP Basic, either username/password or API key/random
        authenticate_with_http_basic do |username, password|
          user = User.try_to_login(username, password)
          # Don't allow using username/password when two-factor auth is active
          if user&.twofa_active?
            render_error :message => 'HTTP Basic authentication is not allowed. Use API key instead', :status => 401
            return
          end

          user ||= User.find_by_api_key(username)
        end
        if user && user.must_change_password?
          render_error :message => 'You must change your password', :status => 403
          return
        end
      end
      # Switch user if requested by an admin user
      if user && user.admin? && (username = api_switch_user_from_request)
        su = User.find_by_login(username)
        if su && su.active?
          logger.info("  User switched by: #{user.login} (id=#{user.id})") if logger
          user = su
        else
          render_error :message => 'Invalid X-Redmine-Switch-User header', :status => 412
        end
      end
    end
    # store current ip address in user object ephemerally
    user.remote_ip = request.remote_ip if user
    user
  end

  def autologin_cookie_name
    Redmine::Configuration['autologin_cookie_name'].presence || 'autologin'
  end

  def try_to_autologin
    if cookies[autologin_cookie_name] && Setting.autologin?
      # auto-login feature starts a new session
      user = User.try_to_autologin(cookies[autologin_cookie_name])
      if user
        reset_session
        start_user_session(user)
      end
      user
    end
  end

  # Sets the logged in user
  def logged_user=(user)
    reset_session
    if user && user.is_a?(User)
      User.current = user
      start_user_session(user)
    else
      User.current = User.anonymous
    end
  end

  # Logs out current user
  def logout_user
    if User.current.logged?
      if autologin = cookies.delete(autologin_cookie_name)
        User.current.delete_autologin_token(autologin)
      end
      User.current.delete_session_token(session[:tk])
      self.logged_user = nil
    end
  end

  # check if login is globally required to access the application
  def check_if_login_required
    # no check needed if user is already logged in
    return true if User.current.logged?

    require_login if Setting.login_required?
  end

  def check_password_change
    if session[:pwd]
      if User.current.must_change_password?
        flash[:error] = l(:error_password_expired)
        redirect_to my_password_path
      else
        session.delete(:pwd)
      end
    end
  end

  def init_twofa_pairing_and_send_code_for(twofa)
    twofa.init_pairing!
    if twofa.send_code(controller: 'twofa', action: 'activate')
      flash[:notice] = l('twofa_code_sent')
    end
    redirect_to controller: 'twofa', action: 'activate_confirm', scheme: twofa.scheme_name
  end

  def check_twofa_activation
    if session[:must_activate_twofa]
      if User.current.must_activate_twofa?
        flash[:warning] = l('twofa_warning_require')
        if Redmine::Twofa.available_schemes.length == 1
          twofa_scheme = Redmine::Twofa.for_twofa_scheme(Redmine::Twofa.available_schemes.first)
          twofa = twofa_scheme.new(User.current)
          init_twofa_pairing_and_send_code_for(twofa)
        else
          redirect_to controller: 'twofa', action: 'select_scheme'
        end
      else
        session.delete(:must_activate_twofa)
      end
    end
  end

  def set_localization(user=User.current)
    lang = nil
    if user && user.logged?
      lang = find_language(user.language)
    end
    if lang.nil? && !Setting.force_default_language_for_anonymous? && request.env['HTTP_ACCEPT_LANGUAGE']
      accept_lang = parse_qvalues(request.env['HTTP_ACCEPT_LANGUAGE']).first
      if accept_lang.present?
        accept_lang = accept_lang.downcase
        lang = find_language(accept_lang) || find_language(accept_lang.split('-').first)
      end
    end
    lang ||= Setting.default_language
    set_language_if_valid(lang)
  end

  def require_login
    if !User.current.logged?
      # Extract only the basic url parameters on non-GET requests
      if request.get?
        url = request.original_url
      else
        url = url_for(:controller => params[:controller], :action => params[:action], :id => params[:id], :project_id => params[:project_id])
      end
      respond_to do |format|
        format.html do
          if request.xhr?
            head :unauthorized
          else
            redirect_to signin_path(:back_url => url)
          end
        end
        format.any(:atom, :pdf, :csv) do
          redirect_to signin_path(:back_url => url)
        end
        format.api do
          if Setting.rest_api_enabled? && accept_api_auth?
            head(:unauthorized, 'WWW-Authenticate' => 'Basic realm="Redmine API"')
          else
            head(:forbidden)
          end
        end
        format.js   {head :unauthorized, 'WWW-Authenticate' => 'Basic realm="Redmine API"'}
        format.any  {head :unauthorized}
      end
      return false
    end
    true
  end

  def require_admin
    return unless require_login

    if !User.current.admin?
      render_403
      return false
    end
    true
  end

  def deny_access
    User.current.logged? ? render_403 : require_login
  end

  # Authorize the user for the requested action
  def authorize(ctrl = params[:controller], action = params[:action], global = false)
    allowed = User.current.allowed_to?({:controller => ctrl, :action => action}, @project || @projects, :global => global)
    if allowed
      true
    else
      if @project && @project.archived?
        @archived_project = @project
        render_403 :message => :notice_not_authorized_archived_project
      elsif @project && !@project.allows_to?(:controller => ctrl, :action => action)
        # Project module is disabled
        render_403
      else
        deny_access
      end
    end
  end

  # Authorize the user for the requested action outside a project
  def authorize_global(ctrl = params[:controller], action = params[:action], global = true)
    authorize(ctrl, action, global)
  end

  # Find project of id params[:id]
  def find_project(project_id=params[:id])
    @project = Project.find(project_id)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Find project of id params[:project_id]
  def find_project_by_project_id
    find_project(params[:project_id])
  end

  # Find project of id params[:id] if present
  def find_optional_project_by_id
    if params[:id].present?
      find_project(params[:id])
    end
  end

  # Find a project based on params[:project_id]
  # and authorize the user for the requested action
  def find_optional_project
    if params[:project_id].present?
      @project = Project.find(params[:project_id])
    end
    authorize_global
  rescue ActiveRecord::RecordNotFound
    User.current.logged? ? render_404 : require_login
    false
  end

  # Finds and sets @project based on @object.project
  def find_project_from_association
    render_404 unless @object.present?

    @project = @object.project
  end

  def find_model_object
    model = self.class.model_object
    if model
      @object = model.find(params[:id])
      self.instance_variable_set('@' + controller_name.singularize, @object) if @object
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def self.model_object(model)
    self.model_object = model
  end

  # Find the issue whose id is the :id parameter
  # Raises a Unauthorized exception if the issue is not visible
  def find_issue
    # Issue.visible.find(...) can not be used to redirect user to the login form
    # if the issue actually exists but requires authentication
    @issue = Issue.find(params[:id])
    raise Unauthorized unless @issue.visible?

    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Find issues with a single :id param or :ids array param
  # Raises a Unauthorized exception if one of the issues is not visible
  def find_issues
    @issues = Issue.
      where(:id => (params[:id] || params[:ids])).
      preload(:project, :status, :tracker, :priority,
              :author, :assigned_to, :relations_to,
              {:custom_values => :custom_field}).
      to_a
    raise ActiveRecord::RecordNotFound if @issues.empty?
    raise Unauthorized unless @issues.all?(&:visible?)

    @projects = @issues.filter_map(&:project).uniq
    @project = @projects.first if @projects.size == 1
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_attachments
    if (attachments = params[:attachments]).present?
      att = attachments.values.collect do |attachment|
        Attachment.find_by_token(attachment[:token]) if attachment[:token].present?
      end
      att.compact!
    end
    @attachments = att || []
  end

  def parse_params_for_bulk_update(params)
    attributes = (params || {}).reject {|k, v| v.blank?}
    if custom = attributes[:custom_field_values]
      custom.reject! {|k, v| v.blank?}
    end

    replace_none_values_with_blank(attributes)
  end

  def replace_none_values_with_blank(params)
    attributes = (params || {})
    attributes.each_key {|k| attributes[k] = '' if attributes[k] == 'none'}
    if (custom = attributes[:custom_field_values])
      custom.each_key do |k|
        if custom[k].is_a?(Array)
          custom[k] << '' if custom[k].delete('__none__')
        else
          custom[k] = '' if custom[k] == '__none__'
        end
      end
    end
    attributes
  end

  # make sure that the user is a member of the project (or admin) if project is private
  # used as a before_action for actions that do not require any particular permission on the project
  def check_project_privacy
    if @project && !@project.archived?
      if @project.visible?
        true
      else
        deny_access
      end
    else
      @project = nil
      render_404
      false
    end
  end

  def record_project_usage
    if @project && @project.id && User.current.logged? && User.current.allowed_to?(:view_project, @project)
      Redmine::ProjectJumpBox.new(User.current).project_used(@project)
    end
    true
  end

  def back_url
    url = params[:back_url]
    if url.nil? && referer = request.env['HTTP_REFERER']
      url = CGI.unescape(referer.to_s)
      # URLs that contains the utf8=[checkmark] parameter added by Rails are
      # parsed as invalid by URI.parse so the redirect to the back URL would
      # not be accepted (ApplicationController#validate_back_url would return
      # false)
      url.gsub!(/(\?|&)utf8=\u2713&?/, '\1')
    end
    url
  end
  helper_method :back_url

  def redirect_back_or_default(default, options={})
    if back_url = validate_back_url(params[:back_url].to_s)
      redirect_to(back_url)
      return
    elsif options[:referer]
      redirect_to_referer_or default
      return
    end
    redirect_to default
    false
  end

  # Returns a validated URL string if back_url is a valid url for redirection,
  # otherwise false
  def validate_back_url(back_url)
    return false if back_url.blank?

    if CGI.unescape(back_url).include?('..')
      return false
    end

    begin
      uri = URI.parse(back_url)
    rescue URI::InvalidURIError
      return false
    end

    [:scheme, :host, :port].each do |component|
      if uri.send(component).present? && uri.send(component) != request.send(component)
        return false
      end

      uri.send(:"#{component}=", nil)
    end
    # Always ignore basic user:password in the URL
    uri.userinfo = nil

    path = uri.to_s
    # Ensure that the remaining URL starts with a slash, followed by a
    # non-slash character or the end
    if !%r{\A/([^/]|\z)}.match?(path)
      return false
    end

    if %r{/(login|account/register|account/lost_password)}.match?(path)
      return false
    end

    if relative_url_root.present? && !path.starts_with?(relative_url_root)
      return false
    end

    return path
  end
  private :validate_back_url
  helper_method :validate_back_url

  def valid_back_url?(back_url)
    !!validate_back_url(back_url)
  end
  private :valid_back_url?
  helper_method :valid_back_url?

  # Redirects to the request referer if present, redirects to args or call block otherwise.
  def redirect_to_referer_or(*args, &block)
    if referer = request.headers["Referer"]
      redirect_to referer
    else
      if args.any?
        redirect_to *args
      elsif block
        yield
      else
        raise "#redirect_to_referer_or takes arguments or a block"
      end
    end
  end

  def render_403(options={})
    @project = nil
    render_error({:message => :notice_not_authorized, :status => 403}.merge(options))
    return false
  end

  def render_404(options={})
    render_error({:message => :notice_file_not_found, :status => 404}.merge(options))
    return false
  end

  # Renders an error response
  def render_error(arg)
    arg = {:message => arg} unless arg.is_a?(Hash)

    @message = arg[:message]
    @message = l(@message) if @message.is_a?(Symbol)
    @status = arg[:status] || 500

    respond_to do |format|
      format.html do
        render :template => 'common/error', :layout => use_layout, :status => @status
      end
      format.any {head @status}
    end
  end

  # Handler for ActionView::MissingTemplate exception
  def missing_template(exception)
    logger.warn "Missing template, responding with 404: #{exception}"
    @project = nil
    render_404
  end

  # Filter for actions that provide an API response
  # but have no HTML representation for non admin users
  def require_admin_or_api_request
    return true if api_request?

    if User.current.admin?
      true
    elsif User.current.logged?
      render_error(:status => 406)
    else
      deny_access
    end
  end

  # Picks which layout to use based on the request
  #
  # @return [boolean, string] name of the layout to use or false for no layout
  def use_layout
    request.xhr? ? false : 'base'
  end

  def render_feed(items, options={})
    @items = (items || []).to_a
    @items.sort! {|x, y| y.event_datetime <=> x.event_datetime}
    @items = @items.slice(0, Setting.feeds_limit.to_i)
    @title = options[:title] || Setting.app_title
    render :template => "common/feed", :formats => [:atom], :layout => false,
           :content_type => 'application/atom+xml'
  end

  def self.accept_atom_auth(*actions)
    if actions.any?
      self.accept_atom_auth_actions = actions
    else
      self.accept_atom_auth_actions || []
    end
  end

  def self.accept_rss_auth(*actions)
    ActiveSupport::Deprecation.warn "Application#self.accept_rss_auth is deprecated and will be removed in Redmine 6.0. Please use #self.accept_atom_auth instead."
    self.class.accept_atom_auth(*actions)
  end

  def accept_atom_auth?(action=action_name)
    self.class.accept_atom_auth.include?(action.to_sym)
  end

  # TODO: remove in Redmine 6.0
  def accept_rss_auth?(action=action_name)
    ActiveSupport::Deprecation.warn "Application#accept_rss_auth? is deprecated and will be removed in Redmine 6.0. Please use #accept_atom_auth? instead."
    accept_atom_auth?(action)
  end

  def self.accept_api_auth(*actions)
    if actions.any?
      self.accept_api_auth_actions = actions
    else
      self.accept_api_auth_actions || []
    end
  end

  def accept_api_auth?(action=action_name)
    self.class.accept_api_auth.include?(action.to_sym)
  end

  # Returns the number of objects that should be displayed
  # on the paginated list
  def per_page_option
    per_page = nil
    if params[:per_page] && Setting.per_page_options_array.include?(params[:per_page].to_s.to_i)
      per_page = params[:per_page].to_s.to_i
      session[:per_page] = per_page
    elsif session[:per_page]
      per_page = session[:per_page]
    else
      per_page = Setting.per_page_options_array.first || 25
    end
    per_page
  end

  # Returns offset and limit used to retrieve objects
  # for an API response based on offset, limit and page parameters
  def api_offset_and_limit(options=params)
    if options[:offset].present?
      offset = options[:offset].to_i
      if offset < 0
        offset = 0
      end
    end
    limit = options[:limit].to_i
    if limit < 1
      limit = 25
    elsif limit > 100
      limit = 100
    end
    if offset.nil? && options[:page].present?
      offset = (options[:page].to_i - 1) * limit
      offset = 0 if offset < 0
    end
    offset ||= 0

    [offset, limit]
  end

  # qvalues http header parser
  # code taken from webrick
  def parse_qvalues(value)
    tmp = []
    if value
      parts = value.split(/,\s*/)
      parts.each do |part|
        if m = %r{^([^\s,]+?)(?:;\s*q=(\d+(?:\.\d+)?))?$}.match(part)
          val = m[1]
          q = (m[2] or 1).to_f
          tmp.push([val, q])
        end
      end
      tmp = tmp.sort_by{|val, q| -q}
      tmp.collect!{|val, q| val}
    end
    return tmp
  rescue
    nil
  end

  # Returns a string that can be used as filename value in Content-Disposition header
  def filename_for_content_disposition(name)
    name
  end

  def api_request?
    %w(xml json).include? params[:format]
  end

  # Returns the API key present in the request
  def api_key_from_request
    if params[:key].present?
      params[:key].to_s
    elsif request.headers["X-Redmine-API-Key"].present?
      request.headers["X-Redmine-API-Key"].to_s
    end
  end

  # Returns the API 'switch user' value if present
  def api_switch_user_from_request
    request.headers["X-Redmine-Switch-User"].to_s.presence
  end

  # Renders a warning flash if obj has unsaved attachments
  def render_attachment_warning_if_needed(obj)
    flash[:warning] = l(:warning_attachments_not_saved, obj.unsaved_attachments.size) if obj.unsaved_attachments.present?
  end

  # Rescues an invalid query statement. Just in case...
  def query_statement_invalid(exception)
    logger.error "Query::StatementInvalid: #{exception.message}" if logger
    session.delete(:issue_query)
    render_error l(:error_query_statement_invalid)
  end

  def query_error(exception)
    Rails.logger.debug "#{exception.class.name}: #{exception.message}"
    Rails.logger.debug "    #{exception.backtrace.join("\n    ")}"

    render_404
  end

  # Renders a 204 response for successful updates or deletions via the API
  def render_api_ok
    render_api_head :no_content
  end

  # Renders a head API response
  def render_api_head(status)
    head status
  end

  # Renders API response on validation failure
  # for an object or an array of objects
  def render_validation_errors(objects)
    messages = Array.wrap(objects).map {|object| object.errors.full_messages}.flatten
    render_api_errors(messages)
  end

  def render_api_errors(*messages)
    @error_messages = messages.flatten
    render :template => 'common/error_messages', :format => [:api], :status => :unprocessable_entity, :layout => nil
  end

  # Overrides #_include_layout? so that #render with no arguments
  # doesn't use the layout for api requests
  def _include_layout?(*args)
    api_request? ? false : super
  end
end
