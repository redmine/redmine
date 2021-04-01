# frozen_string_literal: true

require 'active_support/core_ext/object/to_query'
require 'rack/utils'

module Redmine
  module SudoMode
    class SudoRequired < StandardError
    end

    class Form
      include ActiveModel::Validations

      attr_accessor :password, :original_fields
      validate :check_password

      def initialize(password = nil)
        self.password = password
      end

      def check_password
        unless password.present? && User.current.check_password?(password)
          errors.add(:password, :invalid)
        end
      end
    end

    module Helper
      # Represents params data from hash as hidden fields
      #
      # taken from https://github.com/brianhempel/hash_to_hidden_fields
      def hash_to_hidden_fields(hash)
        cleaned_hash = hash.to_unsafe_h.reject {|k, v| v.nil?}
        pairs = cleaned_hash.to_query.split(Rack::Utils::DEFAULT_SEP)
        tags = pairs.map do |pair|
          key, value = pair.split('=', 2).map {|str| Rack::Utils.unescape(str)}
          hidden_field_tag(key, value)
        end
        tags.join("\n").html_safe
      end
    end

    module Controller
      extend ActiveSupport::Concern

      included do
        around_action :sudo_mode
      end

      # Sudo mode Around Filter
      #
      # Checks the 'last used' timestamp from session and sets the
      # SudoMode::active? flag accordingly.
      #
      # After the request refreshes the timestamp if sudo mode was used during
      # this request.
      def sudo_mode
        if sudo_timestamp_valid?
          SudoMode.active!
        end
        yield
        update_sudo_timestamp! if SudoMode.was_used?
      end

      # This renders the sudo mode form / handles sudo form submission.
      #
      # Call this method in controller actions if sudo permissions are required
      # for processing this request. This approach is good in cases where the
      # action needs to be protected in any case or where the check is simple.
      #
      # In cases where this decision depends on complex conditions in the model,
      # consider the declarative approach using the require_sudo_mode class
      # method and a corresponding declaration in the model that causes it to throw
      # a SudoRequired Error when necessary.
      #
      # All parameter names given are included as hidden fields to be resubmitted
      # along with the password.
      #
      # Returns true when processing the action should continue, false otherwise.
      # If false is returned, render has already been called for display of the
      # password form.
      #
      # if @user.mail_changed?
      #   require_sudo_mode :user or return
      # end
      #
      def require_sudo_mode(*param_names)
        return true if SudoMode.active?

        if param_names.blank?
          param_names = params.keys - %w(id action controller sudo_password _method authenticity_token utf8)
        end

        process_sudo_form

        if SudoMode.active?
          true
        else
          render_sudo_form param_names
          false
        end
      end

      # display the sudo password form
      def render_sudo_form(param_names)
        @sudo_form ||= SudoMode::Form.new
        @sudo_form.original_fields = params.slice( *param_names )
        # a simple 'render "sudo_mode/new"' works when used directly inside an
        # action, but not when called from a before_action:
        respond_to do |format|
          format.html {render 'sudo_mode/new'}
          format.js   {render 'sudo_mode/new'}
        end
      end

      # handle sudo password form submit
      def process_sudo_form
        if params[:sudo_password]
          @sudo_form = SudoMode::Form.new(params[:sudo_password])
          if @sudo_form.valid?
            SudoMode.active!
          else
            flash.now[:error] = l(:notice_account_wrong_password)
          end
        end
      end

      def sudo_timestamp_valid?
        session[:sudo_timestamp].to_i > SudoMode.timeout.ago.to_i
      end

      def update_sudo_timestamp!(new_value = Time.now.to_i)
        session[:sudo_timestamp] = new_value
      end

      # Before Filter which is used by the require_sudo_mode class method.
      class SudoRequestFilter < Struct.new(:parameters, :request_methods)
        def before(controller)
          method_matches = request_methods.blank? || request_methods.include?(controller.request.method_symbol)
          if controller.api_request?
            true
          elsif SudoMode.possible? && method_matches
            controller.require_sudo_mode( *parameters )
          else
            true
          end
        end
      end

      module ClassMethods
        # Handles sudo requirements for the given actions, preserving the named
        # parameters, or any parameters if you omit the :parameters option.
        #
        # Sudo enforcement by default is active for all requests to an action
        # but may be limited to a certain subset of request methods via the
        # :only option.
        #
        # Examples:
        #
        # require_sudo_mode :account, only: :post
        # require_sudo_mode :update, :create, parameters: %w(role)
        # require_sudo_mode :destroy
        #
        def require_sudo_mode(*args)
          actions = args.dup
          options = actions.extract_options!
          filter = SudoRequestFilter.new Array(options[:parameters]), Array(options[:only])
          before_action filter, only: actions
        end
      end
    end

    # true if the sudo mode state was queried during this request
    def self.was_used?
      !!RequestStore.store[:sudo_mode_was_used]
    end

    # true if sudo mode is currently active.
    #
    # Calling this method also turns was_used? to true, therefore
    # it is important to only call this when sudo is actually needed, as the last
    # condition to determine whether a change can be done or not.
    #
    # If you do it wrong, timeout of the sudo mode will happen too late or not at
    # all.
    def self.active?
      if !!RequestStore.store[:sudo_mode]
        RequestStore.store[:sudo_mode_was_used] = true
      end
    end

    def self.active!
      RequestStore.store[:sudo_mode] = true
    end

    def self.possible?
      enabled? && User.current.logged?
    end

    # Turn off sudo mode (never require password entry).
    def self.disable!
      RequestStore.store[:sudo_mode_disabled] = true
    end

    # Turn sudo mode back on
    def self.enable!
      RequestStore.store[:sudo_mode_disabled] = nil
    end

    def self.enabled?
      Redmine::Configuration['sudo_mode'] && !RequestStore.store[:sudo_mode_disabled]
    end

    # Timespan after which sudo mode expires when unused.
    def self.timeout
      m = Redmine::Configuration['sudo_mode_timeout'].to_i
      (m > 0 ? m : 15).minutes
    end
  end
end
