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

require File.expand_path('../../test_helper', __FILE__)

class AttachmentsControllerTest < Redmine::ControllerTest
  fixtures :users, :user_preferences, :projects, :roles, :members, :member_roles,
           :enabled_modules, :issues, :trackers, :attachments, :issue_statuses, :journals, :journal_details,
           :versions, :wiki_pages, :wikis, :documents, :enumerations

  def setup
    User.current = nil
    set_fixtures_attachments_directory
  end

  def teardown
    set_tmp_attachments_directory
  end

  def test_show_diff
    ['inline', 'sbs'].each do |dt|
      # 060719210727_changeset_utf8.diff
      get(
        :show,
        :params => {
          :id => 14,
          :type => dt
        }
      )
      assert_response :success

      assert_equal 'text/html', @response.media_type
      assert_select 'th.filename', :text => /issues_controller.rb\t\(révision 1484\)/
      assert_select 'td.line-code', :text => /Demande créée avec succès/
    end
  end

  def test_show_diff_replace_cannot_convert_content
    with_settings :repositories_encodings => 'UTF-8' do
      ['inline', 'sbs'].each do |dt|
        # 060719210727_changeset_iso8859-1.diff
        get(
          :show,
          :params => {
            :id => 5,
            :type => dt
          }
        )
        assert_response :success

        assert_equal 'text/html', @response.media_type
        assert_select 'th.filename', :text => /issues_controller.rb\t\(r\?vision 1484\)/
        assert_select 'td.line-code', :text => /Demande cr\?\?e avec succ\?s/
      end
    end
  end

  def test_show_diff_latin_1
    with_settings :repositories_encodings => 'UTF-8,ISO-8859-1' do
      ['inline', 'sbs'].each do |dt|
        # 060719210727_changeset_iso8859-1.diff
        get(
          :show,
          :params => {
            :id => 5,
            :type => dt
          }
        )
        assert_response :success

        assert_equal 'text/html', @response.media_type
        assert_select 'th.filename', :text => /issues_controller.rb\t\(révision 1484\)/
        assert_select 'td.line-code', :text => /Demande créée avec succès/
      end
    end
  end

  def test_show_should_save_diff_type_as_user_preference
    user1 = User.find(1)
    user1.pref[:diff_type] = nil
    user1.preference.save
    user = User.find(1)
    assert_nil user.pref[:diff_type]
    @request.session[:user_id] = 1 # admin

    get(
      :show,
      :params => {
        :id => 5
      }
    )
    assert_response :success
    user.reload
    assert_equal "inline", user.pref[:diff_type]

    get(
      :show,
      :params => {
        :id => 5,
        :type => 'sbs'
      }
    )
    assert_response :success
    user.reload
    assert_equal "sbs", user.pref[:diff_type]
  end

  def test_diff_show_filename_in_mercurial_export
    set_tmp_attachments_directory
    a = Attachment.new(:container => Issue.find(1),
                       :file => uploaded_test_file("hg-export.diff", "text/plain"),
                       :author => User.find(1))
    assert a.save
    assert_equal 'hg-export.diff', a.filename
    get(
      :show,
      :params => {
        :id => a.id,
        :type => 'inline'
      }
    )
    assert_response :success
    assert_equal 'text/html', @response.media_type
    assert_select 'th.filename', :text => 'test1.txt'
  end

  def test_show_text_file
    get(:show, :params => {:id => 4})
    assert_response :success
    assert_equal 'text/html', @response.media_type
  end

  def test_show_text_file_utf_8
    set_tmp_attachments_directory
    a = Attachment.new(:container => Issue.find(1),
                       :file => uploaded_test_file("japanese-utf-8.txt", "text/plain"),
                       :author => User.find(1))
    assert a.save
    assert_equal 'japanese-utf-8.txt', a.filename
    get(:show, :params => {:id => a.id})
    assert_response :success
    assert_equal 'text/html', @response.media_type
    assert_select 'tr#L1' do
      assert_select 'th.line-num a[data-txt=?]', '1'
      assert_select 'td', :text => /日本語/
    end
  end

  def test_show_text_file_replace_cannot_convert_content
    set_tmp_attachments_directory
    with_settings :repositories_encodings => 'UTF-8' do
      a = Attachment.new(:container => Issue.find(1),
                         :file => uploaded_test_file("iso8859-1.txt", "text/plain"),
                         :author => User.find(1))
      assert a.save
      assert_equal 'iso8859-1.txt', a.filename
      get(:show, :params => {:id => a.id})
      assert_response :success
      assert_equal 'text/html', @response.media_type
      assert_select 'tr#L7' do
        assert_select 'th.line-num a[data-txt=?]', '7'
        assert_select 'td', :text => /Demande cr\?\?e avec succ\?s/
      end
    end
  end

  def test_show_text_file_latin_1
    set_tmp_attachments_directory
    with_settings :repositories_encodings => 'UTF-8,ISO-8859-1' do
      a = Attachment.new(:container => Issue.find(1),
                         :file => uploaded_test_file("iso8859-1.txt", "text/plain"),
                         :author => User.find(1))
      assert a.save
      assert_equal 'iso8859-1.txt', a.filename
      get(:show, :params => {:id => a.id})
      assert_response :success
      assert_equal 'text/html', @response.media_type
      assert_select 'tr#L7' do
        assert_select 'th.line-num a[data-txt=?]', '7'
        assert_select 'td', :text => /Demande créée avec succès/
      end
    end
  end

  def test_show_text_file_should_show_other_if_too_big
    @request.session[:user_id] = 2
    with_settings :file_max_size_displayed => 512 do
      Attachment.find(4).update_attribute :filesize, 754.kilobyte
      get(:show, :params => {:id => 4})
      assert_response :success
      assert_equal 'text/html', @response.media_type
      assert_select '.nodata', :text => 'No preview available. Download the file instead.'
    end
  end

  def test_show_text_file_formated_markdown
    set_tmp_attachments_directory
    a = Attachment.new(:container => Issue.find(1),
                       :file => uploaded_test_file('testfile.md', 'text/plain'),
                       :author => User.find(1))
    assert a.save
    assert_equal 'testfile.md', a.filename
    get(:show, :params => {:id => a.id})
    assert_response :success
    assert_equal 'text/html', @response.media_type
    assert_select 'div.wiki', :html => "<h1>Header 1</h1>\n\n<h2>Header 2</h2>\n\n<h3>Header 3</h3>"
  end

  def test_show_text_file_fromated_textile
    set_tmp_attachments_directory
    a = Attachment.new(:container => Issue.find(1),
                       :file => uploaded_test_file('testfile.textile', 'text/plain'),
                       :author => User.find(1))
    assert a.save
    assert_equal 'testfile.textile', a.filename
    get(:show, :params => {:id => a.id})
    assert_response :success
    assert_equal 'text/html', @response.media_type
    assert_select 'div.wiki', :html => "<h1>Header 1</h1>\n\n\n\t<h2>Header 2</h2>\n\n\n\t<h3>Header 3</h3>"
  end

  def test_show_image
    @request.session[:user_id] = 2
    get(:show, :params => {:id => 16})
    assert_response :success
    assert_equal 'text/html', @response.media_type
    assert_select 'img.filecontent', :src => attachments(:attachments_010).filename
  end

  def test_show_other_with_no_preview
    @request.session[:user_id] = 2
    get(:show, :params => {:id => 6})
    assert_equal 'text/html', @response.media_type
    assert_select '.nodata', :text => 'No preview available. Download the file instead.'
  end

  def test_show_file_from_private_issue_without_permission
    get(:show, :params => {:id => 15})
    assert_redirected_to '/login?back_url=http%3A%2F%2Ftest.host%2Fattachments%2F15'
  end

  def test_show_file_from_private_issue_with_permission
    @request.session[:user_id] = 2
    get(:show, :params => {:id => 15})
    assert_response :success
    assert_select 'h2', :text => /private.diff/
  end

  def test_show_file_without_container_should_be_allowed_to_author
    set_tmp_attachments_directory
    attachment = Attachment.create!(:file => uploaded_test_file("testfile.txt", "text/plain"), :author_id => 2)
    @request.session[:user_id] = 2
    get(:show, :params => {:id => attachment.id})
    assert_response 200
  end

  def test_show_file_without_container_should_be_denied_to_other_users
    set_tmp_attachments_directory
    attachment = Attachment.create!(:file => uploaded_test_file("testfile.txt", "text/plain"), :author_id => 2)

    @request.session[:user_id] = 3
    get(:show, :params => {:id => attachment.id})
    assert_response 403
  end

  def test_show_issue_attachment_should_highlight_issues_menu_item
    get(:show, :params => {:id => 4})
    assert_response :success
    assert_select '#main-menu a.issues.selected'
  end

  def test_show_invalid_should_respond_with_404
    get(:show, :params => {:id => 999})
    assert_response 404
  end

  def test_show_renders_pagination
    get(:show, :params => {:id => 5, :type => 'inline'})
    assert_response :success

    assert_select 'ul.pages li.next', :text => /next/i
    assert_select 'ul.pages li.previous', :text => /previous/i
  end

  def test_download_text_file
    get(:download, :params => {:id => 4})
    assert_response :success
    assert_equal 'application/x-ruby', @response.media_type
    etag = @response.etag
    assert_not_nil etag

    @request.env["HTTP_IF_NONE_MATCH"] = etag
    get(:download, :params => {:id => 4})
    assert_response 304
  end

  def test_download_js_file
    set_tmp_attachments_directory
    attachment = Attachment.create!(
      :file => mock_file_with_options(:original_filename => "hello.js", :content_type => "text/javascript"),
      :author_id => 2,
      :container => Issue.find(1)
    )

    get(:download, :params => {:id => attachment.id})
    assert_response :success
    assert_equal 'text/javascript', @response.media_type
  end

  def test_download_version_file_with_issue_tracking_disabled
    Project.find(1).disable_module! :issue_tracking
    get(:download, :params => {:id => 9})
    assert_response :success
  end

  def test_download_should_assign_content_type_if_blank
    Attachment.find(4).update_attribute(:content_type, '')
    get(:download, :params => {:id => 4})
    assert_response :success
    assert_equal 'text/x-ruby', @response.media_type
  end

  def test_download_should_assign_better_content_type_than_application_octet_stream
    Attachment.find(4).update! :content_type => "application/octet-stream"
    get(:download, :params => {:id => 4})
    assert_response :success
    assert_equal 'text/x-ruby', @response.media_type
  end

  def test_download_should_assign_application_octet_stream_if_content_type_is_not_determined
    get(:download, :params => {:id => 22})
    assert_response :success
    assert_nil Redmine::MimeType.of(attachments(:attachments_022).filename)
    assert_equal 'application/octet-stream', @response.media_type
  end

  def test_download_missing_file
    get(:download, :params => {:id => 2})
    assert_response 404
  end

  def test_download_should_be_denied_without_permission
    get(:download, :params => {:id => 7})
    assert_redirected_to '/login?back_url=http%3A%2F%2Ftest.host%2Fattachments%2Fdownload%2F7'
  end

  if convert_installed?
    def test_thumbnail
      Attachment.clear_thumbnails
      @request.session[:user_id] = 2
      get(
        :thumbnail,
        :params => {
          :id => 16
        }
      )
      assert_response :success
      assert_equal 'image/png', response.media_type

      etag = @response.etag
      assert_not_nil etag

      @request.env["HTTP_IF_NONE_MATCH"] = etag
      get(
        :thumbnail,
        :params => {
          :id => 16
        }
      )
      assert_response 304
    end

    def test_thumbnail_should_not_exceed_maximum_size
      Redmine::Thumbnail.expects(:generate).with {|source, target, size| size == 800}
      @request.session[:user_id] = 2
      get(
        :thumbnail,
        :params => {
          :id => 16,
          :size => 2000
        }
      )
    end

    def test_thumbnail_should_round_size
      Redmine::Thumbnail.expects(:generate).with {|source, target, size| size == 300}
      @request.session[:user_id] = 2
      get(
        :thumbnail,
        :params => {
          :id => 16,
          :size => 260
        }
      )
    end

    def test_thumbnail_should_return_404_for_non_image_attachment
      @request.session[:user_id] = 2
      get(
        :thumbnail,
        :params => {
          :id => 15
        }
      )
      assert_response 404
    end

    def test_thumbnail_should_return_404_if_thumbnail_generation_failed
      Attachment.any_instance.stubs(:thumbnail).returns(nil)
      @request.session[:user_id] = 2
      get(
        :thumbnail,
        :params => {
          :id => 16
        }
      )
      assert_response 404
    end

    def test_thumbnail_should_be_denied_without_permission
      get(
        :thumbnail,
        :params => {
          :id => 16
        }
      )
      assert_redirected_to '/login?back_url=http%3A%2F%2Ftest.host%2Fattachments%2Fthumbnail%2F16'
    end
  else
    puts '(ImageMagick convert not available)'
  end

  if gs_installed?
    def test_thumbnail_for_pdf_should_be_png
      skip unless convert_installed?

      Attachment.clear_thumbnails
      @request.session[:user_id] = 2
      get(
        :thumbnail,
        :params => {
          :id => 23   # ecookbook-gantt.pdf
        }
      )
      assert_response :success
      assert_equal 'image/png', response.media_type
    end
  else
    puts '(GhostScript convert not available)'
  end

  def test_edit_all
    @request.session[:user_id] = 2
    get(
      :edit_all,
      :params => {
        :object_type => 'issues',
        :object_id => '2'
      }
    )
    assert_response :success

    assert_select 'form[action=?]', '/attachments/issues/2' do
      Issue.find(2).attachments.each do |attachment|
        assert_select "tr#attachment-#{attachment.id}"
      end

      assert_select 'tr#attachment-4' do
        assert_select 'input[name=?][value=?]', 'attachments[4][filename]', 'source.rb'
        assert_select 'input[name=?][value=?]', 'attachments[4][description]', 'This is a Ruby source file'
      end
    end

    # Link to the container in heading
    assert_select 'h2 a', :text => "Feature request #2"
  end

  def test_edit_all_with_invalid_container_class_should_return_404
    get(
      :edit_all,
      :params => {
        :object_type => 'nuggets',
        :object_id => '3'
      }
    )
    assert_response 404
  end

  def test_edit_all_with_invalid_object_should_return_404
    get(
      :edit_all,
      :params => {
        :object_type => 'issues',
        :object_id => '999'
      }
    )
    assert_response 404
  end

  def test_edit_all_for_object_that_is_not_visible_should_return_403
    get(
      :edit_all,
      :params => {
        :object_type => 'issues',
        :object_id => '4'
      }
    )
    assert_response 403
  end

  def test_edit_all_issue_attachment_by_user_without_edit_issue_permission_on_tracker_should_return_404
    role = Role.find(2)
    role.set_permission_trackers 'edit_issues', [2, 3]
    role.save!

    @request.session[:user_id] = 2

    get(
      :edit_all,
      :params => {
        :object_type => 'issues',
        :object_id => '4'
      }
    )
    assert_response 404
  end

  def test_update_all
    @request.session[:user_id] = 2
    patch(
      :update_all,
      :params => {
        :object_type => 'issues',
        :object_id => '2',
        :attachments => {
          '1' => {
            :filename => 'newname.text',
            :description => ''
          },
          '4' => {
            :filename => 'newname.rb',
            :description => 'Renamed'
          },
        }
      }
    )
    assert_response 302
    attachment = Attachment.find(4)
    assert_equal 'newname.rb', attachment.filename
    assert_equal 'Renamed', attachment.description
  end

  def test_update_all_with_failure
    @request.session[:user_id] = 2
    patch(
      :update_all,
      :params => {
        :object_type => 'issues',
        :object_id => '3',
        :attachments => {
          '1' => {
            :filename => '',
            :description => ''
          },
          '4' => {
            :filename => 'newname.rb',
            :description => 'Renamed'
          },
        }
      }
    )
    assert_response :success
    assert_select_error /file cannot be blank/i

    # The other attachment should not be updated
    attachment = Attachment.find(4)
    assert_equal 'source.rb', attachment.filename
    assert_equal 'This is a Ruby source file', attachment.description
  end

  def test_download_all_with_valid_container
    @request.session[:user_id] = 2
    get(
      :download_all,
      :params => {
        :object_type => 'issues',
        :object_id => '2'
      }
    )
    assert_response 200
    assert_equal response.headers['Content-Type'], 'application/zip'
    assert_match /issue-2-attachments.zip/, response.headers['Content-Disposition']
    assert_not_includes Dir.entries(Rails.root.join('tmp')), /attachments_zip/
  end

  def test_download_all_with_invalid_container
    @request.session[:user_id] = 2
    get(
      :download_all,
      :params => {
        :object_type => 'issues',
        :object_id => '999'
      }
    )
    assert_response 404
  end

  def test_download_all_without_readable_attachments
    @request.session[:user_id] = 2
    get(
      :download_all,
      :params => {
        :object_type => 'issues',
        :object_id => '1'
      }
    )
    assert_equal Issue.find(1).attachments, []
    assert_response 404
  end

  def test_download_all_with_maximum_bulk_download_size_larger_than_attachments
    with_settings :bulk_download_max_size => 0 do
      @request.session[:user_id] = 2
      get(
        :download_all,
        :params => {
          :object_type => 'issues',
          :object_id => '2',
          :back_url => '/issues/2'
        }
      )
      assert_redirected_to '/issues/2'
      assert_equal flash[:error], 'These attachments cannot be bulk downloaded because the total file size exceeds the maximum allowed size (0 Bytes)'
    end
  end

  def test_destroy_issue_attachment
    set_tmp_attachments_directory
    issue = Issue.find(3)
    @request.session[:user_id] = 2
    assert_difference 'issue.attachments.count', -1 do
      assert_difference 'Journal.count' do
        delete(
          :destroy,
          :params => {
            :id => 1
          }
        )
        assert_redirected_to '/projects/ecookbook'
      end
    end
    assert_nil Attachment.find_by_id(1)
    j = Journal.order('id DESC').first
    assert_equal issue, j.journalized
    assert_equal 'attachment', j.details.first.property
    assert_equal '1', j.details.first.prop_key
    assert_equal 'error281.txt', j.details.first.old_value
    assert_equal User.find(2), j.user
  end

  def test_destroy_wiki_page_attachment
    set_tmp_attachments_directory
    @request.session[:user_id] = 2
    assert_difference 'Attachment.count', -1 do
      delete(
        :destroy,
        :params => {
          :id => 3
        }
      )
      assert_response 302
    end
  end

  def test_destroy_project_attachment
    set_tmp_attachments_directory
    @request.session[:user_id] = 2
    assert_difference 'Attachment.count', -1 do
      delete(
        :destroy,
        :params => {
          :id => 8
        }
      )
      assert_response 302
    end
  end

  def test_destroy_version_attachment
    set_tmp_attachments_directory
    @request.session[:user_id] = 2
    assert_difference 'Attachment.count', -1 do
      delete(
        :destroy,
        :params => {
          :id => 9
        }
      )
      assert_response 302
    end
  end

  def test_destroy_version_attachment_with_issue_tracking_disabled
    Project.find(1).disable_module! :issue_tracking
    set_tmp_attachments_directory
    @request.session[:user_id] = 2
    assert_difference 'Attachment.count', -1 do
      delete(
        :destroy,
        :params => {
          :id => 9
        }
      )
      assert_response 302
    end
  end

  def test_destroy_without_permission
    set_tmp_attachments_directory
    assert_no_difference 'Attachment.count' do
      delete(
        :destroy,
        :params => {
          :id => 3
        }
      )
    end
    assert_response 302
    assert Attachment.find_by_id(3)
  end

  def test_destroy_issue_attachment_by_user_without_edit_issue_permission_on_tracker
    role = Role.find(2)
    role.set_permission_trackers 'edit_issues', [2, 3]
    role.save!

    @request.session[:user_id] = 2

    set_tmp_attachments_directory
    assert_no_difference 'Attachment.count' do
      delete(
        :destroy,
        :params => {
          :id => 7
        }
      )
    end

    assert_response 403
    assert Attachment.find_by_id(7)
  end
end
