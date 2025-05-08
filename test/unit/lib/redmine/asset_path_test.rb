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

class Redmine::AssetPathTest < ActiveSupport::TestCase
  def setup
    assets_dir = Rails.root.join('test/fixtures/asset_path/foo')
    paths = assets_dir.children.select { |child| child.directory? && !child.basename.to_s.starts_with?('.') }
    @asset_path = Redmine::AssetPath.new(assets_dir, paths, 'plugin_assets/foo/')
    @assets = {}
    @transition_map = {}
    @asset_path.update(transition_map: @transition_map, assets: @assets, load_path: nil)
  end

  test "asset path size" do
    assert_equal 2, @asset_path.paths.size
  end

  test "@transition_map does not contain directories with parent-child relationships" do
    assert_equal '.', @transition_map['plugin_assets/foo']['../images']
    assert_nil   @transition_map['plugin_assets/foo/bar']['../../images/baz']
    assert_equal '..', @transition_map['plugin_assets/foo/bar']['../../images']
  end

  test "update assets" do
    assert_not_nil @assets['plugin_assets/foo/foo.css']
    assert_not_nil @assets['plugin_assets/foo/foo.svg']
  end
end
