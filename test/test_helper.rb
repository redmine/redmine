# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

#require 'shoulda'
ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'rails/test_help'
require Rails.root.join('test', 'mocks', 'open_id_authentication_mock.rb').to_s

require File.expand_path(File.dirname(__FILE__) + '/object_helpers')
include ObjectHelpers

class ActiveSupport::TestCase
  include ActionDispatch::TestProcess

  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = false

  def log_user(login, password)
    User.anonymous
    get "/login"
    assert_equal nil, session[:user_id]
    assert_response :success
    assert_template "account/login"
    post "/login", :username => login, :password => password
    assert_equal login, User.find(session[:user_id]).login
  end

  def uploaded_test_file(name, mime)
    fixture_file_upload("files/#{name}", mime, true)
  end

  def credentials(user, password=nil)
    {'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(user, password || user)}
  end

  # Mock out a file
  def self.mock_file
    file = 'a_file.png'
    file.stubs(:size).returns(32)
    file.stubs(:original_filename).returns('a_file.png')
    file.stubs(:content_type).returns('image/png')
    file.stubs(:read).returns(false)
    file
  end

  def mock_file
    self.class.mock_file
  end

  def mock_file_with_options(options={})
    file = ''
    file.stubs(:size).returns(32)
    original_filename = options[:original_filename] || nil
    file.stubs(:original_filename).returns(original_filename)
    content_type = options[:content_type] || nil
    file.stubs(:content_type).returns(content_type)
    file.stubs(:read).returns(false)
    file
  end

  # Use a temporary directory for attachment related tests
  def set_tmp_attachments_directory
    Dir.mkdir "#{Rails.root}/tmp/test" unless File.directory?("#{Rails.root}/tmp/test")
    unless File.directory?("#{Rails.root}/tmp/test/attachments")
      Dir.mkdir "#{Rails.root}/tmp/test/attachments"
    end
    Attachment.storage_path = "#{Rails.root}/tmp/test/attachments"
  end

  def set_fixtures_attachments_directory
    Attachment.storage_path = "#{Rails.root}/test/fixtures/files"
  end

  def with_settings(options, &block)
    saved_settings = options.keys.inject({}) do |h, k|
      h[k] = case Setting[k]
        when Symbol, false, true, nil
          Setting[k]
        else
          Setting[k].dup
        end
      h
    end
    options.each {|k, v| Setting[k] = v}
    yield
  ensure
    saved_settings.each {|k, v| Setting[k] = v} if saved_settings
  end

  # Yields the block with user as the current user
  def with_current_user(user, &block)
    saved_user = User.current
    User.current = user
    yield
  ensure
    User.current = saved_user
  end

  def change_user_password(login, new_password)
    user = User.where(:login => login).first
    user.password, user.password_confirmation = new_password, new_password
    user.save!
  end

  def self.ldap_configured?
    @test_ldap = Net::LDAP.new(:host => '127.0.0.1', :port => 389)
    return @test_ldap.bind
  rescue Exception => e
    # LDAP is not listening
    return nil
  end

  def self.convert_installed?
    Redmine::Thumbnail.convert_available?
  end

  # Returns the path to the test +vendor+ repository
  def self.repository_path(vendor)
    Rails.root.join("tmp/test/#{vendor.downcase}_repository").to_s
  end

  # Returns the url of the subversion test repository
  def self.subversion_repository_url
    path = repository_path('subversion')
    path = '/' + path unless path.starts_with?('/')
    "file://#{path}"
  end

  # Returns true if the +vendor+ test repository is configured
  def self.repository_configured?(vendor)
    File.directory?(repository_path(vendor))
  end

  def repository_path_hash(arr)
    hs = {}
    hs[:path]  = arr.join("/")
    hs[:param] = arr.join("/")
    hs
  end

  def assert_save(object)
    saved = object.save
    message = "#{object.class} could not be saved"
    errors = object.errors.full_messages.map {|m| "- #{m}"}
    message << ":\n#{errors.join("\n")}" if errors.any?
    assert_equal true, saved, message
  end

  def assert_error_tag(options={})
    assert_tag({:attributes => { :id => 'errorExplanation' }}.merge(options))
  end

  def assert_include(expected, s, message=nil)
    assert s.include?(expected), (message || "\"#{expected}\" not found in \"#{s}\"")
  end

  def assert_not_include(expected, s)
    assert !s.include?(expected), "\"#{expected}\" found in \"#{s}\""
  end

  def assert_select_in(text, *args, &block)
    d = HTML::Document.new(CGI::unescapeHTML(String.new(text))).root
    assert_select(d, *args, &block)
  end

  def assert_mail_body_match(expected, mail)
    if expected.is_a?(String)
      assert_include expected, mail_body(mail)
    else
      assert_match expected, mail_body(mail)
    end
  end

  def assert_mail_body_no_match(expected, mail)
    if expected.is_a?(String)
      assert_not_include expected, mail_body(mail)
    else
      assert_no_match expected, mail_body(mail)
    end
  end

  def mail_body(mail)
    mail.parts.first.body.encoded
  end
end

module Redmine
  module ApiTest
    # Base class for API tests
    class Base < ActionDispatch::IntegrationTest
      # Test that a request allows the three types of API authentication
      #
      # * HTTP Basic with username and password
      # * HTTP Basic with an api key for the username
      # * Key based with the key=X parameter
      #
      # @param [Symbol] http_method the HTTP method for request (:get, :post, :put, :delete)
      # @param [String] url the request url
      # @param [optional, Hash] parameters additional request parameters
      # @param [optional, Hash] options additional options
      # @option options [Symbol] :success_code Successful response code (:success)
      # @option options [Symbol] :failure_code Failure response code (:unauthorized)
      def self.should_allow_api_authentication(http_method, url, parameters={}, options={})
        should_allow_http_basic_auth_with_username_and_password(http_method, url, parameters, options)
        should_allow_http_basic_auth_with_key(http_method, url, parameters, options)
        should_allow_key_based_auth(http_method, url, parameters, options)
      end
    
      # Test that a request allows the username and password for HTTP BASIC
      #
      # @param [Symbol] http_method the HTTP method for request (:get, :post, :put, :delete)
      # @param [String] url the request url
      # @param [optional, Hash] parameters additional request parameters
      # @param [optional, Hash] options additional options
      # @option options [Symbol] :success_code Successful response code (:success)
      # @option options [Symbol] :failure_code Failure response code (:unauthorized)
      def self.should_allow_http_basic_auth_with_username_and_password(http_method, url, parameters={}, options={})
        success_code = options[:success_code] || :success
        failure_code = options[:failure_code] || :unauthorized
    
        context "should allow http basic auth using a username and password for #{http_method} #{url}" do
          context "with a valid HTTP authentication" do
            setup do
              @user = User.generate! do |user|
                user.admin = true
                user.password = 'my_password'
              end
              send(http_method, url, parameters, credentials(@user.login, 'my_password'))
            end
    
            should_respond_with success_code
            should_respond_with_content_type_based_on_url(url)
            should "login as the user" do
              assert_equal @user, User.current
            end
          end
    
          context "with an invalid HTTP authentication" do
            setup do
              @user = User.generate!
              send(http_method, url, parameters, credentials(@user.login, 'wrong_password'))
            end
    
            should_respond_with failure_code
            should_respond_with_content_type_based_on_url(url)
            should "not login as the user" do
              assert_equal User.anonymous, User.current
            end
          end
    
          context "without credentials" do
            setup do
              send(http_method, url, parameters)
            end
    
            should_respond_with failure_code
            should_respond_with_content_type_based_on_url(url)
            should "include_www_authenticate_header" do
              assert @controller.response.headers.has_key?('WWW-Authenticate')
            end
          end
        end
      end
    
      # Test that a request allows the API key with HTTP BASIC
      #
      # @param [Symbol] http_method the HTTP method for request (:get, :post, :put, :delete)
      # @param [String] url the request url
      # @param [optional, Hash] parameters additional request parameters
      # @param [optional, Hash] options additional options
      # @option options [Symbol] :success_code Successful response code (:success)
      # @option options [Symbol] :failure_code Failure response code (:unauthorized)
      def self.should_allow_http_basic_auth_with_key(http_method, url, parameters={}, options={})
        success_code = options[:success_code] || :success
        failure_code = options[:failure_code] || :unauthorized
    
        context "should allow http basic auth with a key for #{http_method} #{url}" do
          context "with a valid HTTP authentication using the API token" do
            setup do
              @user = User.generate! do |user|
                user.admin = true
              end
              @token = Token.create!(:user => @user, :action => 'api')
              send(http_method, url, parameters, credentials(@token.value, 'X'))
            end
            should_respond_with success_code
            should_respond_with_content_type_based_on_url(url)
            should_be_a_valid_response_string_based_on_url(url)
            should "login as the user" do
              assert_equal @user, User.current
            end
          end
    
          context "with an invalid HTTP authentication" do
            setup do
              @user = User.generate!
              @token = Token.create!(:user => @user, :action => 'feeds')
              send(http_method, url, parameters, credentials(@token.value, 'X'))
            end
            should_respond_with failure_code
            should_respond_with_content_type_based_on_url(url)
            should "not login as the user" do
              assert_equal User.anonymous, User.current
            end
          end
        end
      end
    
      # Test that a request allows full key authentication
      #
      # @param [Symbol] http_method the HTTP method for request (:get, :post, :put, :delete)
      # @param [String] url the request url, without the key=ZXY parameter
      # @param [optional, Hash] parameters additional request parameters
      # @param [optional, Hash] options additional options
      # @option options [Symbol] :success_code Successful response code (:success)
      # @option options [Symbol] :failure_code Failure response code (:unauthorized)
      def self.should_allow_key_based_auth(http_method, url, parameters={}, options={})
        success_code = options[:success_code] || :success
        failure_code = options[:failure_code] || :unauthorized
    
        context "should allow key based auth using key=X for #{http_method} #{url}" do
          context "with a valid api token" do
            setup do
              @user = User.generate! do |user|
                user.admin = true
              end
              @token = Token.create!(:user => @user, :action => 'api')
              # Simple url parse to add on ?key= or &key=
              request_url = if url.match(/\?/)
                              url + "&key=#{@token.value}"
                            else
                              url + "?key=#{@token.value}"
                            end
              send(http_method, request_url, parameters)
            end
            should_respond_with success_code
            should_respond_with_content_type_based_on_url(url)
            should_be_a_valid_response_string_based_on_url(url)
            should "login as the user" do
              assert_equal @user, User.current
            end
          end
    
          context "with an invalid api token" do
            setup do
              @user = User.generate! do |user|
                user.admin = true
              end
              @token = Token.create!(:user => @user, :action => 'feeds')
              # Simple url parse to add on ?key= or &key=
              request_url = if url.match(/\?/)
                              url + "&key=#{@token.value}"
                            else
                              url + "?key=#{@token.value}"
                            end
              send(http_method, request_url, parameters)
            end
            should_respond_with failure_code
            should_respond_with_content_type_based_on_url(url)
            should "not login as the user" do
              assert_equal User.anonymous, User.current
            end
          end
        end
    
        context "should allow key based auth using X-Redmine-API-Key header for #{http_method} #{url}" do
          setup do
            @user = User.generate! do |user|
              user.admin = true
            end
            @token = Token.create!(:user => @user, :action => 'api')
            send(http_method, url, parameters, {'X-Redmine-API-Key' => @token.value.to_s})
          end
          should_respond_with success_code
          should_respond_with_content_type_based_on_url(url)
          should_be_a_valid_response_string_based_on_url(url)
          should "login as the user" do
            assert_equal @user, User.current
          end
        end
      end
    
      # Uses should_respond_with_content_type based on what's in the url:
      #
      # '/project/issues.xml' => should_respond_with_content_type :xml
      # '/project/issues.json' => should_respond_with_content_type :json
      #
      # @param [String] url Request
      def self.should_respond_with_content_type_based_on_url(url)
        case
        when url.match(/xml/i)
          should "respond with XML" do
            assert_equal 'application/xml', @response.content_type
          end
        when url.match(/json/i)
          should "respond with JSON" do
            assert_equal 'application/json', @response.content_type
          end
        else
          raise "Unknown content type for should_respond_with_content_type_based_on_url: #{url}"
        end
      end
    
      # Uses the url to assert which format the response should be in
      #
      # '/project/issues.xml' => should_be_a_valid_xml_string
      # '/project/issues.json' => should_be_a_valid_json_string
      #
      # @param [String] url Request
      def self.should_be_a_valid_response_string_based_on_url(url)
        case
        when url.match(/xml/i)
          should_be_a_valid_xml_string
        when url.match(/json/i)
          should_be_a_valid_json_string
        else
          raise "Unknown content type for should_be_a_valid_response_based_on_url: #{url}"
        end
      end
    
      # Checks that the response is a valid JSON string
      def self.should_be_a_valid_json_string
        should "be a valid JSON string (or empty)" do
          assert(response.body.blank? || ActiveSupport::JSON.decode(response.body))
        end
      end
    
      # Checks that the response is a valid XML string
      def self.should_be_a_valid_xml_string
        should "be a valid XML string" do
          assert REXML::Document.new(response.body)
        end
      end
    
      def self.should_respond_with(status)
        should "respond with #{status}" do
          assert_response status
        end
      end
    end
  end
end

# URL helpers do not work with config.threadsafe!
# https://github.com/rspec/rspec-rails/issues/476#issuecomment-4705454
ActionView::TestCase::TestController.instance_eval do
  helper Rails.application.routes.url_helpers
end
ActionView::TestCase::TestController.class_eval do
  def _routes
    Rails.application.routes
  end
end
