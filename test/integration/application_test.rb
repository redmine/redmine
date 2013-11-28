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

require File.expand_path('../../test_helper', __FILE__)

class ApplicationTest < ActionController::IntegrationTest
  include Redmine::I18n

  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules

  def test_set_localization
    Setting.default_language = 'en'

    # a french user
    get 'projects', { }, 'HTTP_ACCEPT_LANGUAGE' => 'fr,fr-fr;q=0.8,en-us;q=0.5,en;q=0.3'
    assert_response :success
    assert_tag :tag => 'h2', :content => 'Projets'
    assert_equal :fr, current_language
    assert_select "html[lang=?]", "fr"

    # then an italien user
    get 'projects', { }, 'HTTP_ACCEPT_LANGUAGE' => 'it;q=0.8,en-us;q=0.5,en;q=0.3'
    assert_response :success
    assert_tag :tag => 'h2', :content => 'Progetti'
    assert_equal :it, current_language
    assert_select "html[lang=?]", "it"

    # not a supported language: default language should be used
    get 'projects', { }, 'HTTP_ACCEPT_LANGUAGE' => 'zz'
    assert_response :success
    assert_tag :tag => 'h2', :content => 'Projects'
    assert_select "html[lang=?]", "en"
  end

  def test_token_based_access_should_not_start_session
    # issue of a private project
    get 'issues/4.atom'
    assert_response 302

    rss_key = User.find(2).rss_key
    get "issues/4.atom?key=#{rss_key}"
    assert_response 200
    assert_nil session[:user_id]
  end

  def test_missing_template_should_respond_with_404
    get '/login.png'
    assert_response 404
  end
end
