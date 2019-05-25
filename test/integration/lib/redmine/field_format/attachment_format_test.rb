# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

class AttachmentFieldFormatTest < Redmine::IntegrationTest
  fixtures :projects,
           :users, :email_addresses,
           :roles,
           :members,
           :member_roles,
           :trackers,
           :projects_trackers,
           :enabled_modules,
           :issue_statuses,
           :issues,
           :enumerations,
           :custom_fields,
           :custom_values,
           :custom_fields_trackers,
           :attachments

  def setup
    User.current = nil
    set_tmp_attachments_directory
    @field = IssueCustomField.generate!(:name => "File", :field_format => "attachment")
    log_user "jsmith", "jsmith"
  end

  def test_new_should_include_inputs
    get '/projects/ecookbook/issues/new'
    assert_response :success

    assert_select '[name^=?]', "issue[custom_field_values][#{@field.id}]", 2
    assert_select 'input[name=?][type=hidden][value=""]', "issue[custom_field_values][#{@field.id}][blank]"
  end

  def test_create_with_attachment
    issue = new_record(Issue) do
      assert_difference 'Attachment.count' do
        post '/projects/ecookbook/issues', :params => {
            :issue => {
              :subject => "Subject",
              :custom_field_values => {
                @field.id => {
                  'blank' => '',
                  '1' => {:file => uploaded_test_file("testfile.txt", "text/plain")}
                }
              }
            }
          }
        assert_response 302
      end
    end

    custom_value = issue.custom_value_for(@field)
    assert custom_value
    assert custom_value.value.present?

    attachment = Attachment.find_by_id(custom_value.value)
    assert attachment
    assert_equal custom_value, attachment.container

    follow_redirect!
    assert_response :success

    # link to the attachment
    link = css_select(".cf_#{@field.id} .value a")
    assert_equal 1, link.size
    assert_equal "testfile.txt", link.text

    # preview the attachment
    get link.attr('href')
    assert_response :success
    assert_select 'h2', :text => "#{issue.tracker} ##{issue.id} » testfile.txt"
  end

  def test_create_without_attachment
    issue = new_record(Issue) do
      assert_no_difference 'Attachment.count' do
        post '/projects/ecookbook/issues', :params => {
            :issue => {
              :subject => "Subject",
              :custom_field_values => {
                @field.id => {:blank => ''}
              }
            }
          }
        assert_response 302
      end
    end

    custom_value = issue.custom_value_for(@field)
    assert custom_value
    assert custom_value.value.blank?

    follow_redirect!
    assert_response :success

    # no links to the attachment
    assert_select ".cf_#{@field.id} .value a", 0
  end

  def test_failure_on_create_should_preserve_attachment
    attachment = new_record(Attachment) do
      assert_no_difference 'Issue.count' do
        post '/projects/ecookbook/issues', :params => {
            :issue => {
              :subject => "",
              :custom_field_values => {
                @field.id => {:file => uploaded_test_file("testfile.txt", "text/plain")}
              }
            }
          }
        assert_response :success
        assert_select_error /Subject cannot be blank/
      end
    end

    assert_nil attachment.container_id
    assert_select 'input[name=?][value=?][type=hidden]', "issue[custom_field_values][#{@field.id}][p0][token]", attachment.token
    assert_select 'input[name=?][value=?]', "issue[custom_field_values][#{@field.id}][p0][filename]", 'testfile.txt'

    issue = new_record(Issue) do
      assert_no_difference 'Attachment.count' do
        post '/projects/ecookbook/issues', :params => {
            :issue => {
              :subject => "Subject",
              :custom_field_values => {
                @field.id => {:token => attachment.token}
              }
            }
          }
        assert_response 302
      end
    end

    custom_value = issue.custom_value_for(@field)
    assert custom_value
    assert_equal attachment.id.to_s, custom_value.value
    assert_equal custom_value, attachment.reload.container
  end

  def test_create_with_valid_extension
    @field.extensions_allowed = "txt, log"
    @field.save!

    attachment = new_record(Attachment) do
      assert_difference 'Issue.count' do
        post '/projects/ecookbook/issues', :params => {
            :issue => {
              :subject => "Blank",
              :custom_field_values => {
                @field.id => {:file => uploaded_test_file("testfile.txt", "text/plain")}
              }
            }
          }
        assert_response 302
      end
    end
  end

  def test_create_with_invalid_extension_should_fail
    @field.extensions_allowed = "png, jpeg"
    @field.save!

    attachment = new_record(Attachment) do
      assert_no_difference 'Issue.count' do
        post '/projects/ecookbook/issues', :params => {
            :issue => {
              :subject => "Blank",
              :custom_field_values => {
                @field.id => {:file => uploaded_test_file("testfile.txt", "text/plain")}
              }
            }
          }
        assert_response :success
      end
    end
  end
end
