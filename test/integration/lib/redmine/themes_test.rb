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

require_relative '../../../test_helper'

class ThemesTest < Redmine::IntegrationTest
  def setup
    Redmine::Themes.rescan
    @theme = Redmine::Themes.theme('classic')
    Setting.ui_theme = @theme.id
  end

  def teardown
    Setting.ui_theme = ''
  end

  def test_application_css
    get '/'

    assert_response :success
    assert_select "link[rel=stylesheet]:match('href', ?)", %r{/assets/themes/#{@theme.dir}/application-\w+\.css}
  end

  def test_without_theme_js
    # simulate a state theme.js does not exists
    @theme.javascripts.clear
    get '/'

    assert_response :success
    assert_select "script[src^=?]", "/assets/themes/#{@theme.dir}/theme.js", 0
  end

  def test_with_theme_js
    # Simulates a theme.js
    @theme.javascripts << 'theme'
    get '/'

    assert_response :success
    assert_select "script[src^=?]", "/assets/themes/#{@theme.dir}/theme.js", 1
  ensure
    @theme.javascripts.delete 'theme'
  end

  def test_use_default_favicon_if_theme_provides_none
    @theme.favicons.clear
    get '/'

    assert_response :success
    assert_select "link[rel='shortcut icon']:match('href',?)", %r{/assets/favicon-\w+\.ico}
  end

  def test_use_theme_favicon_if_theme_provides_one
    # Simulate a theme favicon
    @theme.favicons.unshift('a.ico')
    get '/'

    assert_response :success
    assert_select 'link[rel="shortcut icon"][href^=?]', "/assets/themes/#{@theme.dir}/a.ico"
  ensure
    @theme.favicons.delete 'a.ico'
  end

  def test_use_only_one_theme_favicon_if_theme_provides_many
    @theme.favicons.unshift('b.ico', 'a.png')
    get '/'

    assert_response :success
    assert_select 'link[rel="shortcut icon"]', 1
    assert_select 'link[rel="shortcut icon"][href^=?]', "/assets/themes/#{@theme.dir}/b.ico"
  ensure
    @theme.favicons.delete("b.ico")
    @theme.favicons.delete("a.png")
  end

  def test_with_sub_uri
    Redmine::Utils.relative_url_root = '/foo'
    @theme.javascripts.unshift('theme')
    @theme.favicons.unshift('a.ico')
    get '/'

    assert_response :success
    assert_select "link[rel=stylesheet]:match('href', ?)", %r{/foo/assets/themes/#{@theme.dir}/application-\w+\.css}
    assert_select "script[src^=?]", "/foo/assets/themes/#{@theme.dir}/theme.js"
    assert_select 'link[rel="shortcut icon"][href^=?]', "/foo/assets/themes/#{@theme.dir}/a.ico"
  ensure
    Redmine::Utils.relative_url_root = ''
  end

  def test_body_css_class_with_spaces_in_theme_name
    @theme.instance_variable_set(:@name, 'Foo bar baz')
    get '/'

    assert_response :success
    assert_select 'body[class~="theme-Foo_bar_baz"]'
  end

  def test_old_theme_compatibility
    @theme = Redmine::Themes::Theme.new(Rails.root.join('test/fixtures/themes/foo_theme'))
    Rails.application.config.assets.redmine_extension_paths << @theme.asset_paths
    Setting.ui_theme = @theme.id
    Rails.application.assets.load_path.clear_cache

    asset = Rails.application.assets.load_path.find('themes/foo_theme/application.css')
    get "/assets/#{asset.digested_path}"

    assert_response :success
    assert_match %r{url\("/assets/application-\w+\.css"\)}, response.body
  end
end
