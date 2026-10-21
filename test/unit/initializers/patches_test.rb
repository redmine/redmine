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

require_relative '../../test_helper'

class PatchesTest < ActiveSupport::TestCase
  include Redmine::I18n
  include ActionView::Helpers::FormHelper

  def setup
    Setting.default_language = 'en'
  end

  test "ApplicationRecord.human_attribute_name should transform name to field_name" do
    assert_equal l('field_last_login_on'), ApplicationRecord.human_attribute_name('last_login_on')
  end

  test "ApplicationRecord.human_attribute_name should cut extra _id suffix for better validation" do
    assert_equal l('field_last_login_on'), ApplicationRecord.human_attribute_name('last_login_on_id')
  end

  test "ApplicationRecord.human_attribute_name should default to humanized value if no translation has been found (useful for custom fields)" do
    assert_equal 'Patch name', ApplicationRecord.human_attribute_name('Patch name')
  end

  test 'ActionView::Helpers::FormHelper.date_field should add max=9999-12-31 to limit year value to 4 digits by default' do
    assert_include 'max="9999-12-31"', date_field('issue', 'start_date')
    assert_include 'max="2099-12-31"', date_field('issue', 'start_date', max: '2099-12-31')
  end

  test 'ActionView::Helpers::FormTagHelper.date_field_tag should add max=9999-12-31 to limit year value to 4 digits by default' do
    assert_include 'max="9999-12-31"', date_field_tag('start_date')
    assert_include 'max="2099-12-31"', date_field_tag('issue', 'start_date', max: '2099-12-31')
  end

  test 'Propshaft::Assembly#manifest_outdated? should return false when the on-disk manifest matches the current assets' do
    with_manifest_content(Rails.application.assets.load_path.manifest.to_json) do
      assert_not Rails.application.assets.manifest_outdated?
    end
  end

  test 'Propshaft::Assembly#manifest_outdated? should return true when the on-disk manifest differs from the current assets' do
    with_manifest_content('{}') do
      assert Rails.application.assets.manifest_outdated?
    end
  end

  test 'Propshaft::Assembly#manifest_outdated? should return true instead of raising when the manifest file contains invalid JSON' do
    with_manifest_content('not valid json') do
      assert Rails.application.assets.manifest_outdated?
    end
  end

  test 'Propshaft::Assembly#needs_precompile? should return true when there is no manifest file' do
    without_manifest_file do
      assert Rails.application.assets.needs_precompile?
    end
  end

  private

  # Temporarily replaces the content of the real asset manifest file with
  # +content+ for the duration of the block, restoring (or removing) it
  # afterwards.
  def with_manifest_content(content)
    manifest_path = Rails.application.assets.config.manifest_path
    manifest_path.dirname.mkpath
    original = manifest_path.read if manifest_path.exist?

    manifest_path.write(content)
    yield
  ensure
    if original
      manifest_path.write(original)
    elsif manifest_path.exist?
      manifest_path.delete
    end
  end

  # Temporarily removes the real asset manifest file for the duration of the
  # block, restoring it afterwards if it existed.
  def without_manifest_file
    manifest_path = Rails.application.assets.config.manifest_path
    original = manifest_path.read if manifest_path.exist?
    manifest_path.delete if manifest_path.exist?

    yield
  ensure
    manifest_path.write(original) if original
  end
end
