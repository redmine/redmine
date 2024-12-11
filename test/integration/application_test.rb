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

require_relative '../test_helper'

class ApplicationTest < Redmine::IntegrationTest
  include Redmine::I18n

  def test_set_localization
    Setting.default_language = 'en'

    # a french user
    get '/projects', :headers => {'HTTP_ACCEPT_LANGUAGE' => 'fr,fr-fr;q=0.8,en-us;q=0.5,en;q=0.3'}
    assert_response :success
    assert_select 'h2', :text => 'Projets'
    assert_equal :fr, current_language
    assert_select "html[lang=?]", "fr"

    # then an italien user
    get '/projects', :headers => {'HTTP_ACCEPT_LANGUAGE' => 'it;q=0.8,en-us;q=0.5,en;q=0.3'}
    assert_response :success
    assert_select 'h2', :text => 'Progetti'
    assert_equal :it, current_language
    assert_select "html[lang=?]", "it"

    # not a supported language: default language should be used
    get '/projects', :headers => {'HTTP_ACCEPT_LANGUAGE' => 'zz'}
    assert_response :success
    assert_select 'h2', :text => 'Projects'
    assert_select "html[lang=?]", "en"
  end

  def test_token_based_access_should_not_start_session
    # issue of a private project
    get '/issues/4.atom'
    assert_response :found

    atom_key = User.find(2).atom_key
    get "/issues/4.atom?key=#{atom_key}"
    assert_response :ok
    assert_nil session[:user_id]
  end

  def test_missing_template_should_respond_with_4xx
    get '/login.png'
    assert_response :not_acceptable
  end

  def test_invalid_token_should_call_custom_handler
    ActionController::Base.allow_forgery_protection = true
    post '/issues'
    assert_response :unprocessable_content
    assert_include "Invalid form authenticity token.", response.body
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  def test_localization_should_be_set_correctly_on_invalid_token
    ActionController::Base.allow_forgery_protection = true
    Setting.default_language = 'en'
    post '/issues', :headers => {'HTTP_ACCEPT_LANGUAGE' => 'fr,fr-fr;q=0.8,en-us;q=0.5,en;q=0.3'}
    assert_response :unprocessable_content
    assert_equal :fr, current_language
    assert_select "html[lang=?]", "fr"
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  def test_require_login_with_pdf_format_should_not_error
    with_settings :login_required => '1' do
      get '/issues/1.pdf'
      assert_response :found
    end
  end

  def test_find_optional_project_should_not_error
    Role.anonymous.remove_permission! :view_gantt
    with_settings :login_required => '0' do
      get '/projects/nonexistingproject/issues/gantt'
      assert_response :found
    end
  end

  def test_find_optional_project_should_render_404_for_logged_users
    log_user('jsmith', 'jsmith')

    get '/projects/nonexistingproject/issues/gantt'
    assert_response :not_found
  end
end
