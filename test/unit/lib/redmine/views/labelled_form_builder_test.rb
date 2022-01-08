# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

require File.expand_path('../../../../../test_helper', __FILE__)

class Redmine::Views::LabelledFormBuilderTest < Redmine::HelperTest
  include Rails.application.routes.url_helpers

  def test_label_should_output_one_element
    set_language_if_valid 'en'
    labelled_form_for(Issue.new) do |f|
      output = f.label :subject
      assert_equal output, '<label for="issue_subject">Subject</label>'
    end
  end

  def test_hours_field_should_display_formatted_value_if_valid
    entry = TimeEntry.new(:hours => '2.5')
    entry.validate

    labelled_form_for(entry) do |f|
      assert_include 'value="2:30"', f.hours_field(:hours)
    end
  end

  def test_hours_field_should_display_entered_value_if_invalid
    entry = TimeEntry.new(:hours => '2.z')
    entry.validate

    labelled_form_for(entry) do |f|
      assert_include 'value="2.z"', f.hours_field(:hours)
    end
  end
end
