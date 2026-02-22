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

class Redmine::ThemesTest < ActiveSupport::TestCase
  def test_themes
    themes = Redmine::Themes.themes
    assert_kind_of Array, themes
    assert_kind_of Redmine::Themes::Theme, themes.first
  end

  def test_rescan
    Redmine::Themes.themes.pop

    assert_difference 'Redmine::Themes.themes.size' do
      Redmine::Themes.rescan
    end
  end

  def test_theme_loaded
    theme = Redmine::Themes.themes.last

    assert_equal theme, Redmine::Themes.theme(theme.id)
  end

  def test_theme_loaded_without_rescan
    theme = Redmine::Themes.themes.last

    assert_equal theme, Redmine::Themes.theme(theme.id, :rescan => false)
  end

  def test_theme_not_loaded
    theme = Redmine::Themes.themes.pop

    assert_equal theme, Redmine::Themes.theme(theme.id)
  end

  def test_theme_not_loaded_without_rescan
    theme = Redmine::Themes.themes.pop

    assert_nil Redmine::Themes.theme(theme.id, :rescan => false)
  ensure
    Redmine::Themes.rescan
  end

  def test_icons_should_return_available_icons
    theme = Redmine::Themes::Theme.new('/tmp/test')
    theme.stubs(:image_path).with('icons.svg').returns('themes/test/icons.svg')

    asset = mock('asset')
    asset.stubs(:content).returns('<svg><symbol id="icon--edit"></symbol><symbol id=\'icon--delete\'></symbol></svg>')
    asset.stubs(:digest).returns('123456')

    Rails.application.assets.load_path.stubs(:find).with('themes/test/icons.svg').returns(asset)

    assert_equal ['edit', 'delete'], theme.icons('icons')
  end

  def test_icons_should_return_empty_array_if_asset_missing
    theme = Redmine::Themes::Theme.new('/tmp/test')
    theme.stubs(:image_path).with('icons.svg').returns('themes/test/icons.svg')

    Rails.application.assets.load_path.stubs(:find).with('themes/test/icons.svg').returns(nil)

    assert_equal [], theme.icons('icons')
  end

  def test_icons_should_be_cached
    theme = Redmine::Themes::Theme.new('/tmp/test')
    theme.stubs(:id).returns('test')
    theme.stubs(:image_path).with('icons.svg').returns('themes/test/icons.svg')

    asset = mock('asset')
    asset.stubs(:content).returns('<symbol id="icon--edit"></symbol>')
    asset.stubs(:digest).returns('123456')

    Rails.application.assets.load_path.stubs(:find).with('themes/test/icons.svg').returns(asset)

    # Use a memory store for this test since the test environment uses null_store
    memory_store = ActiveSupport::Cache.lookup_store(:memory_store)
    ActionController::Base.stubs(:cache_store).returns(memory_store)

    # First call - cache miss
    assert_equal ['edit'], theme.icons('icons')

    # Second call - verify it's in the cache
    cache_key = "theme-icons/test/icons/123456"
    assert_equal ['edit'], memory_store.read(cache_key)

    # If digest changes, it should miss cache
    asset.stubs(:digest).returns('789')
    asset.stubs(:content).returns('<symbol id="icon--new"></symbol>')
    assert_equal ['new'], theme.icons('icons')
  end
end
