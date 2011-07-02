# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
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

require File.expand_path('../../../test_helper', __FILE__)

class PatchesTest < ActiveSupport::TestCase
  include Redmine::I18n

  context "ActiveRecord::Base.human_attribute_name" do
    setup do
      Setting.default_language = 'en'
    end

    should "transform name to field_name" do
      assert_equal l('field_last_login_on'), ActiveRecord::Base.human_attribute_name('last_login_on')
    end

    should "cut extra _id suffix for better validation" do
      assert_equal l('field_last_login_on'), ActiveRecord::Base.human_attribute_name('last_login_on_id')
    end

    should "default to humanized value if no translation has been found (useful for custom fields)" do
      assert_equal 'Patch name', ActiveRecord::Base.human_attribute_name('Patch name')
    end
  end
end
