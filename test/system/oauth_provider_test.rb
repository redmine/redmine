# frozen_string_literal: true

require_relative '../application_system_test_case'
require 'oauth2'
require 'rack'
require 'puma'

class OauthProviderSystemTest < ApplicationSystemTestCase
  test 'application creation and authorization' do
    #
    # admin creates the application, granting permissions and generating a uuid
    # and secret.
    #
    log_user 'admin', 'admin'
    with_settings rest_api_enabled: 1 do
      visit '/admin'
      within 'div#admin-menu ul' do
        click_link 'Applications'
      end
      click_link 'New Application'
      fill_in 'Name', with: 'Oauth Test'

      # as per https://tools.ietf.org/html/rfc8252#section-7.3, the port can be
      # anything when the redirect URI's host is 127.0.0.1.
      fill_in 'Redirect URI', with: 'http://127.0.0.1'

      check 'View Issues'
      click_button 'Create'

      assert_text "Application created."
    end

    assert app = Doorkeeper::Application.find_by_name('Oauth Test')

    find 'h2', visible: true, text: /Oauth Test/
    find 'p code', visible: true, text: app.uid
    find 'p strong', visible: true, text: /will not be shown again/
    find 'p code', visible: true, text: /View Issues/

    # scrape the clear text secret from the page
    app_secret = all(:css, 'p code')[1].text

    click_link 'Sign out'

    #
    # regular user authorizes the application
    #
    client = OAuth2::Client.new(app.uid, app_secret, site: "http://127.0.0.1:#{test_port}/")

    # set up a dummy http listener to handle the redirect
    port = rand 10000..20000
    redirect_uri = "http://127.0.0.1:#{port}"
    # the request handler below will set this to the auth token
    token = nil

    # launches webrick, listening for the redirect with the auth code.
    launch_client_app(port: port) do |req, res|
      # get access code from code url param
      if code = req.params['code'].presence
        # exchange it for token
        token = client.auth_code.get_token(code, redirect_uri: redirect_uri)
        res.body = ["<html><body><p>Authorization succeeded, you may close this window now.</p></body></html>"]
      end
    end

    log_user 'jsmith', 'jsmith'
    with_settings rest_api_enabled: 1 do
      visit '/my/account'
      click_link 'Authorized applications'
      find 'p.nodata', visible: true

      # an oauth client would send the user to this url to request permission
      url = client.auth_code.authorize_url redirect_uri: redirect_uri, scope: 'view_issues view_project'
      uri = URI.parse url
      visit uri.path + '?' + uri.query

      find 'h2', visible: true, text: 'Authorization required'
      find 'p', visible: true, text: /Authorize Oauth Test/
      find '.oauth-permissions', visible: true, text: /View Issues/
      find '.oauth-permissions', visible: true, text: /View project/

      click_button 'Authorize'

      assert grant = app.access_grants.last
      assert_equal 'view_issues view_project', grant.scopes.to_s

      # check for output defined above in the request handler
      find 'p', visible: true, text: /Authorization succeeded/
      assert token.present?

      visit '/my/account'
      click_link 'Authorized applications'
      find 'td', visible: true, text: /Oauth Test/
      click_link 'Sign out'

      # Now, use the token for some API requests
      assert_raise(RestClient::Unauthorized) do
        RestClient.get "http://localhost:#{test_port}/projects/onlinestore/issues.json"
      end

      headers = { 'Authorization' => "Bearer #{token.token}" }
      r = RestClient.get "http://localhost:#{test_port}/projects/onlinestore/issues.json", headers
      issues = JSON.parse(r.body)['issues']
      assert issues.any?

      # time entries access is not part of the granted scopes
      assert_raise(RestClient::Forbidden) do
        RestClient.get "http://localhost:#{test_port}/projects/onlinestore/time_entries.json", headers
      end
    end
  end

  private

  def launch_client_app(port: 12345, path: '/', &block)
    app = ->(env) do
      req = Rack::Request.new(env)
      res = Rack::Response.new
      yield(req, res)
      res.finish
    end

    server = Puma::Server.new app
    server.add_tcp_listener '127.0.0.1', port
    Thread.new { server.run }
  end

  def test_port
    Capybara.current_session.server.port
  end
end
