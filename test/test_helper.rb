# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

if ENV["COVERAGE"]
  require 'simplecov'
  require File.expand_path(File.dirname(__FILE__) + "/coverage/html_formatter")
  SimpleCov.formatter = Redmine::Coverage::HtmlFormatter
  SimpleCov.start 'rails'
end

ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'rails/test_help'
require Rails.root.join('test', 'mocks', 'open_id_authentication_mock.rb').to_s

require File.expand_path(File.dirname(__FILE__) + '/object_helpers')
include ObjectHelpers

require 'net/ldap'
require 'mocha/setup'

Redmine::SudoMode.disable!

class ActionView::TestCase
  helper :application
  include ApplicationHelper
end

class ActiveSupport::TestCase
  include ActionDispatch::TestProcess

  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = false

  def uploaded_test_file(name, mime)
    fixture_file_upload("files/#{name}", mime, true)
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

  def with_locale(locale, &block)
    saved_localed = ::I18n.locale
    ::I18n.locale = locale
    yield
  ensure
    ::I18n.locale = saved_localed
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

  def convert_installed?
    self.class.convert_installed?
  end

  # Returns the path to the test +vendor+ repository
  def self.repository_path(vendor)
    path = Rails.root.join("tmp/test/#{vendor.downcase}_repository").to_s
    # Unlike ruby, JRuby returns Rails.root with backslashes under Windows
    path.tr("\\", "/")
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

  def sqlite?
    ActiveRecord::Base.connection.adapter_name =~ /sqlite/i
  end

  def mysql?
    ActiveRecord::Base.connection.adapter_name =~ /mysql/i
  end

  def postgresql?
    ActiveRecord::Base.connection.adapter_name =~ /postgresql/i
  end

  def quoted_date(date)
    date = Date.parse(date) if date.is_a?(String)
    ActiveRecord::Base.connection.quoted_date(date)
  end

  # Asserts that a new record for the given class is created
  # and returns it
  def new_record(klass, &block)
    new_records(klass, 1, &block).first
  end

  # Asserts that count new records for the given class are created
  # and returns them as an array order by object id
  def new_records(klass, count, &block)
    assert_difference "#{klass}.count", count do
      yield
    end
    klass.order(:id => :desc).limit(count).to_a.reverse
  end

  def assert_save(object)
    saved = object.save
    message = "#{object.class} could not be saved"
    errors = object.errors.full_messages.map {|m| "- #{m}"}
    message << ":\n#{errors.join("\n")}" if errors.any?
    assert_equal true, saved, message
  end

  def assert_select_error(arg)
    assert_select '#errorExplanation', :text => arg
  end

  def assert_include(expected, s, message=nil)
    assert s.include?(expected), (message || "\"#{expected}\" not found in \"#{s}\"")
  end

  def assert_not_include(expected, s, message=nil)
    assert !s.include?(expected), (message || "\"#{expected}\" found in \"#{s}\"")
  end

  def assert_select_in(text, *args, &block)
    d = Nokogiri::HTML(CGI::unescapeHTML(String.new(text))).root
    assert_select(d, *args, &block)
  end

  def assert_select_email(*args, &block)
    email = ActionMailer::Base.deliveries.last
    assert_not_nil email
    html_body = email.parts.detect {|part| part.content_type.include?('text/html')}.try(&:body)
    assert_not_nil html_body
    assert_select_in html_body.encoded, *args, &block
  end

  def assert_mail_body_match(expected, mail, message=nil)
    if expected.is_a?(String)
      assert_include expected, mail_body(mail), message
    else
      assert_match expected, mail_body(mail), message
    end
  end

  def assert_mail_body_no_match(expected, mail, message=nil)
    if expected.is_a?(String)
      assert_not_include expected, mail_body(mail), message
    else
      assert_no_match expected, mail_body(mail), message
    end
  end

  def mail_body(mail)
    mail.parts.first.body.encoded
  end

  # Returns the lft value for a new root issue
  def new_issue_lft
    1
  end
end

module Redmine
  class RoutingTest < ActionDispatch::IntegrationTest
    def should_route(arg)
      arg = arg.dup
      request = arg.keys.detect {|key| key.is_a?(String)}
      raise ArgumentError unless request
      options = arg.slice!(request)

      raise ArgumentError unless request =~ /\A(GET|POST|PUT|PATCH|DELETE)\s+(.+)\z/
      method, path = $1.downcase.to_sym, $2

      raise ArgumentError unless arg.values.first =~ /\A(.+)#(.+)\z/
      controller, action = $1, $2

      assert_routing(
        {:method => method, :path => path},
        options.merge(:controller => controller, :action => action)
      )
    end
  end

  class IntegrationTest < ActionDispatch::IntegrationTest
    def log_user(login, password)
      User.anonymous
      get "/login"
      assert_equal nil, session[:user_id]
      assert_response :success
      assert_template "account/login"
      post "/login", :username => login, :password => password
      assert_equal login, User.find(session[:user_id]).login
    end

    def credentials(user, password=nil)
      {'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(user, password || user)}
    end
  end

  module ApiTest
    API_FORMATS = %w(json xml).freeze

    # Base class for API tests
    class Base < Redmine::IntegrationTest
      def setup
        Setting.rest_api_enabled = '1'
      end

      def teardown
        Setting.rest_api_enabled = '0'
      end

      # Uploads content using the XML API and returns the attachment token
      def xml_upload(content, credentials)
        upload('xml', content, credentials)
      end

      # Uploads content using the JSON API and returns the attachment token
      def json_upload(content, credentials)
        upload('json', content, credentials)
      end

      def upload(format, content, credentials)
        set_tmp_attachments_directory
        assert_difference 'Attachment.count' do
          post "/uploads.#{format}", content, {"CONTENT_TYPE" => 'application/octet-stream'}.merge(credentials)
          assert_response :created
        end
        data = response_data
        assert_kind_of Hash, data['upload']
        token = data['upload']['token']
        assert_not_nil token
        token
      end

      # Parses the response body based on its content type
      def response_data
        unless response.content_type.to_s =~ /^application\/(.+)/
          raise "Unexpected response type: #{response.content_type}"
        end
        format = $1
        case format
        when 'xml'
          Hash.from_xml(response.body)
        when 'json'
          ActiveSupport::JSON.decode(response.body)
        else
          raise "Unknown response format: #{format}"
        end
      end
    end

    class Routing < Redmine::RoutingTest
      def should_route(arg)
        arg = arg.dup
        request = arg.keys.detect {|key| key.is_a?(String)}
        raise ArgumentError unless request
        options = arg.slice!(request)
  
        API_FORMATS.each do |format|
          format_request = request.sub /$/, ".#{format}"
          super options.merge(format_request => arg[request], :format => format)
        end
      end
    end
  end
end
