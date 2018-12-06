# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

class WikiControllerTest < Redmine::ControllerTest
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :enabled_modules, :wikis, :wiki_pages, :wiki_contents,
           :wiki_content_versions, :attachments,
           :issues, :issue_statuses, :trackers

  def setup
    User.current = nil
  end

  def test_show_start_page
    get :show, :params => {:project_id => 'ecookbook'}
    assert_response :success

    assert_select 'h1', :text => /CookBook documentation/
    # child_pages macro
    assert_select 'ul.pages-hierarchy>li>a[href=?]', '/projects/ecookbook/wiki/Page_with_an_inline_image',
      :text => 'Page with an inline image'
  end

  def test_export_link
    Role.anonymous.add_permission! :export_wiki_pages
    get :show, :params => {:project_id => 'ecookbook'}
    assert_response :success
    assert_select 'a[href=?]', '/projects/ecookbook/wiki/CookBook_documentation.txt'
  end

  def test_show_page_with_name
    get :show, :params => {:project_id => 1, :id => 'Another_page'}
    assert_response :success

    assert_select 'h1', :text => /Another page/
    # Included page with an inline image
    assert_select 'p', :text => /This is an inline image/
    assert_select 'img[src=?][alt=?]', '/attachments/download/3/logo.gif', 'This is a logo'
  end

  def test_show_old_version
    with_settings :default_language => 'en' do
      get :show, :params => {:project_id => 'ecookbook', :id => 'CookBook_documentation', :version => '2'}
    end
    assert_response :success

    assert_select 'a[href=?]', '/projects/ecookbook/wiki/CookBook_documentation/1', :text => /Previous/
    assert_select 'a[href=?]', '/projects/ecookbook/wiki/CookBook_documentation/2/diff', :text => /diff/
    assert_select 'a[href=?]', '/projects/ecookbook/wiki/CookBook_documentation/3', :text => /Next/
  end

  def test_show_old_version_with_attachments
    page = WikiPage.find(4)
    assert page.attachments.any?
    content = page.content
    content.text = "update"
    content.save!

    get :show, :params => {:project_id => 'ecookbook', :id => page.title, :version => '1'}
    assert_response :success
  end

  def test_show_old_version_without_permission_should_be_denied
    Role.anonymous.remove_permission! :view_wiki_edits

    get :show, :params => {:project_id => 'ecookbook', :id => 'CookBook_documentation', :version => '2'}
    assert_redirected_to '/login?back_url=http%3A%2F%2Ftest.host%2Fprojects%2Fecookbook%2Fwiki%2FCookBook_documentation%2F2'
  end

  def test_show_first_version
    with_settings :default_language => 'en' do
      get :show, :params => {:project_id => 'ecookbook', :id => 'CookBook_documentation', :version => '1'}
    end
    assert_response :success

    assert_select 'a', :text => /Previous/, :count => 0
    assert_select 'a', :text => /diff/, :count => 0
    assert_select 'a[href=?]', '/projects/ecookbook/wiki/CookBook_documentation/2', :text => /Next/
  end

  def test_show_redirected_page
    WikiRedirect.create!(:wiki_id => 1, :title => 'Old_title', :redirects_to => 'Another_page')

    get :show, :params => {:project_id => 'ecookbook', :id => 'Old_title'}
    assert_redirected_to '/projects/ecookbook/wiki/Another_page'
  end

  def test_show_with_sidebar
    page = Project.find(1).wiki.pages.new(:title => 'Sidebar')
    page.content = WikiContent.new(:text => 'Side bar content for test_show_with_sidebar')
    page.save!

    get :show, :params => {:project_id => 1, :id => 'Another_page'}
    assert_response :success
    assert_select 'div#sidebar', :text => /Side bar content for test_show_with_sidebar/
  end

  def test_show_should_display_section_edit_links
    @request.session[:user_id] = 2
    get :show, :params => {:project_id => 1, :id => 'Page with sections'}

    assert_select 'a[href=?]', '/projects/ecookbook/wiki/Page_with_sections/edit?section=1', 0
    assert_select 'a[href=?]', '/projects/ecookbook/wiki/Page_with_sections/edit?section=2'
    assert_select 'a[href=?]', '/projects/ecookbook/wiki/Page_with_sections/edit?section=3'
  end

  def test_show_current_version_should_display_section_edit_links
    @request.session[:user_id] = 2
    get :show, :params => {:project_id => 1, :id => 'Page with sections', :version => 3}

    assert_select 'a[href=?]', '/projects/ecookbook/wiki/Page_with_sections/edit?section=2'
  end

  def test_show_old_version_should_not_display_section_edit_links
    @request.session[:user_id] = 2
    get :show, :params => {:project_id => 1, :id => 'Page with sections', :version => 2}

    assert_select 'a[href=?]', '/projects/ecookbook/wiki/Page_with_sections/edit?section=2', 0
  end

  def test_show_unexistent_page_without_edit_right
    get :show, :params => {:project_id => 1, :id => 'Unexistent page'}
    assert_response 404
  end

  def test_show_unexistent_page_with_edit_right
    @request.session[:user_id] = 2
    get :show, :params => {:project_id => 1, :id => 'Unexistent page'}
    assert_response :success
    assert_select 'textarea[name=?]', 'content[text]'
  end

  def test_show_specific_version_of_an_unexistent_page_without_edit_right
    get :show, :params => {:project_id => 1, :id => 'Unexistent page', :version => 1}
    assert_response 404
  end

  def test_show_unexistent_page_with_parent_should_preselect_parent
    @request.session[:user_id] = 2
    get :show, :params => {:project_id => 1, :id => 'Unexistent page', :parent => 'Another_page'}
    assert_response :success
    assert_select 'select[name=?] option[value="2"][selected=selected]', 'wiki_page[parent_id]'
  end

  def test_show_should_not_show_history_without_permission
    Role.anonymous.remove_permission! :view_wiki_edits
    get :show, :params => {:project_id => 1, :id => 'Page with sections', :version => 2}

    assert_response 302
  end

  def test_show_page_without_content_should_display_the_edit_form
    @request.session[:user_id] = 2
    WikiPage.create!(:title => 'NoContent', :wiki => Project.find(1).wiki)

    get :show, :params => {:project_id => 1, :id => 'NoContent'}
    assert_response :success
    assert_select 'textarea[name=?]', 'content[text]'
  end

  def test_get_new
    @request.session[:user_id] = 2

    get :new, :params => {:project_id => 'ecookbook'}
    assert_response :success
    assert_select 'input[name=?]', 'title'
  end

  def test_get_new_xhr
    @request.session[:user_id] = 2

    get :new, :params => {:project_id => 'ecookbook'}, :xhr => true
    assert_response :success
    assert_include 'Unallowed characters', response.body
  end

  def test_post_new_with_valid_title_should_redirect_to_edit
    @request.session[:user_id] = 2

    post :new, :params => {:project_id => 'ecookbook', :title => 'New Page'}
    assert_redirected_to '/projects/ecookbook/wiki/New_Page'
  end

  def test_post_new_xhr_with_valid_title_should_redirect_to_edit
    @request.session[:user_id] = 2

    post :new, :params => {:project_id => 'ecookbook', :title => 'New Page'}, :xhr => true
    assert_response :success
    assert_equal 'window.location = "/projects/ecookbook/wiki/New_Page"', response.body
  end

  def test_post_new_should_redirect_to_edit_with_parent
    @request.session[:user_id] = 2

    post :new, :params => {:project_id => 'ecookbook', :title => 'New_Page', :parent => 'Child_1'}
    assert_redirected_to '/projects/ecookbook/wiki/New_Page?parent=Child_1'
  end

  def test_post_new_with_invalid_title_should_display_errors
    @request.session[:user_id] = 2

    post :new, :params => {:project_id => 'ecookbook', :title => 'Another page'}
    assert_response :success
    assert_select_error 'Title has already been taken'
  end

  def test_post_new_with_protected_title_should_display_errors
    Role.find(1).remove_permission!(:protect_wiki_pages)
    @request.session[:user_id] = 2

    post :new, :params => {:project_id => 'ecookbook', :title => 'Sidebar'}
    assert_response :success
    assert_select_error /Title/
  end

  def test_post_new_xhr_with_invalid_title_should_display_errors
    @request.session[:user_id] = 2

    post :new, :params => {:project_id => 'ecookbook', :title => 'Another page'}, :xhr => true
    assert_response :success
    assert_include 'Title has already been taken', response.body
  end

  def test_create_page
    @request.session[:user_id] = 2
    assert_difference 'WikiPage.count' do
      assert_difference 'WikiContent.count' do
        put :update, :params => {
          :project_id => 1,
          :id => 'New page',
          :content => {
            :comments => 'Created the page',
            :text => "h1. New page\n\nThis is a new page",
            :version => 0
          }
        }
      end
    end
    assert_redirected_to :action => 'show', :project_id => 'ecookbook', :id => 'New_page'
    page = Project.find(1).wiki.find_page('New page')
    assert !page.new_record?
    assert_not_nil page.content
    assert_nil page.parent
    assert_equal 'Created the page', page.content.comments
  end

  def test_create_page_with_attachments
    @request.session[:user_id] = 2
    assert_difference 'WikiPage.count' do
      assert_difference 'Attachment.count' do
        put :update, :params => {
          :project_id => 1,
          :id => 'New page',
          :content => {
            :comments => 'Created the page',
            :text => "h1. New page\n\nThis is a new page",
            :version => 0
          },
          :attachments => {'1' => {'file' => uploaded_test_file('testfile.txt', 'text/plain')}}
        }
      end
    end
    page = Project.find(1).wiki.find_page('New page')
    assert_equal 1, page.attachments.count
    assert_equal 'testfile.txt', page.attachments.first.filename
  end

  def test_create_page_with_parent
    @request.session[:user_id] = 2
    assert_difference 'WikiPage.count' do
      put :update, :params => {
        :project_id => 1,
        :id => 'New page',
        :content => {
          :text => "h1. New page\n\nThis is a new page",
          :version => 0
        },
        :wiki_page => {:parent_id => 2}
      }
    end
    page = Project.find(1).wiki.find_page('New page')
    assert_equal WikiPage.find(2), page.parent
  end

  def test_edit_page
    @request.session[:user_id] = 2
    get :edit, :params => {:project_id => 'ecookbook', :id => 'Another_page'}

    assert_response :success

    assert_select 'textarea[name=?]', 'content[text]',
      :text => WikiPage.find_by_title('Another_page').content.text
  end

  def test_edit_section
    @request.session[:user_id] = 2
    get :edit, :params => {:project_id => 'ecookbook', :id => 'Page_with_sections', :section => 2}

    assert_response :success

    page = WikiPage.find_by_title('Page_with_sections')
    section, hash = Redmine::WikiFormatting::Textile::Formatter.new(page.content.text).get_section(2)

    assert_select 'textarea[name=?]', 'content[text]', :text => section
    assert_select 'input[name=section][type=hidden][value="2"]'
    assert_select 'input[name=section_hash][type=hidden][value=?]', hash
  end

  def test_edit_invalid_section_should_respond_with_404
    @request.session[:user_id] = 2
    get :edit, :params => {:project_id => 'ecookbook', :id => 'Page_with_sections', :section => 10}

    assert_response 404
  end

  def test_update_page
    @request.session[:user_id] = 2
    assert_no_difference 'WikiPage.count' do
      assert_no_difference 'WikiContent.count' do
        assert_difference 'WikiContentVersion.count' do
          put :update, :params => {
            :project_id => 1,
            :id => 'Another_page',
            :content => {
              :comments => "my comments",
              :text => "edited",
              :version => 1
            }
          }
        end
      end
    end
    assert_redirected_to '/projects/ecookbook/wiki/Another_page'

    page = Wiki.find(1).pages.find_by_title('Another_page')
    assert_equal "edited", page.content.text
    assert_equal 2, page.content.version
    assert_equal "my comments", page.content.comments
  end

  def test_update_page_with_parent
    @request.session[:user_id] = 2
    assert_no_difference 'WikiPage.count' do
      assert_no_difference 'WikiContent.count' do
        assert_difference 'WikiContentVersion.count' do
          put :update, :params => {
            :project_id => 1,
            :id => 'Another_page',
            :content => {
              :comments => "my comments",
              :text => "edited",
              :version => 1
            },
            :wiki_page => {:parent_id => '1'}
          }
        end
      end
    end
    assert_redirected_to '/projects/ecookbook/wiki/Another_page'

    page = Wiki.find(1).pages.find_by_title('Another_page')
    assert_equal "edited", page.content.text
    assert_equal 2, page.content.version
    assert_equal "my comments", page.content.comments
    assert_equal WikiPage.find(1), page.parent
  end

  def test_update_page_with_failure
    @request.session[:user_id] = 2
    assert_no_difference 'WikiPage.count' do
      assert_no_difference 'WikiContent.count' do
        assert_no_difference 'WikiContentVersion.count' do
          put :update, :params => {
            :project_id => 1,
            :id => 'Another_page',
            :content => {
              :comments => 'a' * 1300,  # failure here, comment is too long
              :text => 'edited'
            },
            :wiki_page => {
              :parent_id => ""
            }
          }
        end
      end
    end
    assert_response :success

    assert_select_error /Comment is too long/
    assert_select 'textarea#content_text', :text => "edited"
    assert_select 'input#content_version[value="1"]'
  end

  def test_update_page_with_parent_change_only_should_not_create_content_version
    @request.session[:user_id] = 2
    assert_no_difference 'WikiPage.count' do
      assert_no_difference 'WikiContent.count' do
        assert_no_difference 'WikiContentVersion.count' do
          put :update, :params => {
            :project_id => 1,
            :id => 'Another_page',
            :content => {
              :comments => '',
              :text => Wiki.find(1).find_page('Another_page').content.text,
              :version => 1
            },
            :wiki_page => {:parent_id => '1'}
          }
        end
      end
    end
    page = Wiki.find(1).pages.find_by_title('Another_page')
    assert_equal 1, page.content.version
    assert_equal WikiPage.find(1), page.parent
  end

  def test_update_page_with_attachments_only_should_not_create_content_version
    @request.session[:user_id] = 2
    assert_no_difference 'WikiPage.count' do
      assert_no_difference 'WikiContent.count' do
        assert_no_difference 'WikiContentVersion.count' do
          assert_difference 'Attachment.count' do
            put :update, :params => {
              :project_id => 1,
              :id => 'Another_page',
              :content => {
                :comments => '',
                :text => Wiki.find(1).find_page('Another_page').content.text,
                :version => 1
              },
              :attachments => {'1' => {'file' => uploaded_test_file('testfile.txt', 'text/plain'), 'description' => 'test file'}}
            }
          end
        end
      end
    end
    page = Wiki.find(1).pages.find_by_title('Another_page')
    assert_equal 1, page.content.version
  end

  def test_update_with_deleted_attachment_ids
    @request.session[:user_id] = 2
    page = WikiPage.find(4)
    attachment = page.attachments.first
    assert_difference 'Attachment.count', -1 do
      put :update, :params => {
        :project_id => page.wiki.project.id,
        :id => page.title,
        :content => {
          :comments => 'delete file',
          :text => 'edited'
        },
        :wiki_page => {:deleted_attachment_ids => [attachment.id]}
      }
    end
    page.reload
    refute_includes page.attachments, attachment
  end

  def test_update_with_deleted_attachment_ids_and_failure_should_preserve_selected_attachments
    @request.session[:user_id] = 2
    page = WikiPage.find(4)
    attachment = page.attachments.first
    assert_no_difference 'Attachment.count' do
      put :update, :params => {
        :project_id => page.wiki.project.id,
        :id => page.title,
        :content => {
          :comments => 'a' * 1300,  # failure here, comment is too long
          :text => 'edited'
        },
        :wiki_page => {:deleted_attachment_ids => [attachment.id]}
      }
    end
    page.reload
    assert_includes page.attachments, attachment
  end

  def test_update_stale_page_should_not_raise_an_error
    @request.session[:user_id] = 2
    c = Wiki.find(1).find_page('Another_page').content
    c.text = 'Previous text'
    c.save!
    assert_equal 2, c.version

    assert_no_difference 'WikiPage.count' do
      assert_no_difference 'WikiContent.count' do
        assert_no_difference 'WikiContentVersion.count' do
          put :update, :params => {
            :project_id => 1,
            :id => 'Another_page',
            :content => {
              :comments => 'My comments',
              :text => 'Text should not be lost',
              :version => 1
            }
          }
        end
      end
    end
    assert_response :success
    assert_select 'div.error', :text => /Data has been updated by another user/
    assert_select 'textarea[name=?]', 'content[text]', :text => /Text should not be lost/
    assert_select 'input[name=?][value=?]', 'content[comments]', 'My comments'

    c.reload
    assert_equal 'Previous text', c.text
    assert_equal 2, c.version
  end

  def test_update_page_without_content_should_create_content
    @request.session[:user_id] = 2
    page = WikiPage.create!(:title => 'NoContent', :wiki => Project.find(1).wiki)

    assert_no_difference 'WikiPage.count' do
      assert_difference 'WikiContent.count' do
        put :update, :params => {
          :project_id => 1,
          :id => 'NoContent',
          :content => {:text => 'Some content'}
        }
        assert_response 302
      end
    end
    assert_equal 'Some content', page.reload.content.text
  end

  def test_update_section
    @request.session[:user_id] = 2
    page = WikiPage.find_by_title('Page_with_sections')
    section, hash = Redmine::WikiFormatting::Textile::Formatter.new(page.content.text).get_section(2)
    text = page.content.text

    assert_no_difference 'WikiPage.count' do
      assert_no_difference 'WikiContent.count' do
        assert_difference 'WikiContentVersion.count' do
          put :update, :params => {
            :project_id => 1,
            :id => 'Page_with_sections',
            :content => {
              :text => "New section content",
              :version => 3
            },
            :section => 2,
            :section_hash => hash
          }
        end
      end
    end
    assert_redirected_to '/projects/ecookbook/wiki/Page_with_sections#section-2'
    assert_equal Redmine::WikiFormatting::Textile::Formatter.new(text).update_section(2, "New section content"), page.reload.content.text
  end

  def test_update_section_should_allow_stale_page_update
    @request.session[:user_id] = 2
    page = WikiPage.find_by_title('Page_with_sections')
    section, hash = Redmine::WikiFormatting::Textile::Formatter.new(page.content.text).get_section(2)
    text = page.content.text

    assert_no_difference 'WikiPage.count' do
      assert_no_difference 'WikiContent.count' do
        assert_difference 'WikiContentVersion.count' do
          put :update, :params => {
            :project_id => 1,
            :id => 'Page_with_sections',
            :content => {
              :text => "New section content",
              :version => 2 # Current version is 3
            },
            :section => 2,
            :section_hash => hash
          }
        end
      end
    end
    assert_redirected_to '/projects/ecookbook/wiki/Page_with_sections#section-2'
    page.reload
    assert_equal Redmine::WikiFormatting::Textile::Formatter.new(text).update_section(2, "New section content"), page.content.text
    assert_equal 4, page.content.version
  end

  def test_update_section_should_not_allow_stale_section_update
    @request.session[:user_id] = 2

    assert_no_difference 'WikiPage.count' do
      assert_no_difference 'WikiContent.count' do
        assert_no_difference 'WikiContentVersion.count' do
          put :update, :params => {
            :project_id => 1,
            :id => 'Page_with_sections',
            :content => {
              :comments => 'My comments',
              :text => "Text should not be lost",
              :version => 3
            },
            :section => 2,
            :section_hash => Digest::MD5.hexdigest("wrong hash")
          }
        end
      end
    end
    assert_response :success
    assert_select 'div.error', :text => /Data has been updated by another user/
    assert_select 'textarea[name=?]', 'content[text]', :text => /Text should not be lost/
    assert_select 'input[name=?][value=?]', 'content[comments]', 'My comments'
  end

  def test_preview
    @request.session[:user_id] = 2
    post :preview, :params => {
      :project_id => 1,
      :id => 'CookBook_documentation',
      :content => {
        :comments => '',
        :text => 'this is a *previewed text*',
        :version => 3
      }
    }, :xhr => true
    assert_response :success
    assert_select 'strong', :text => /previewed text/
  end

  def test_preview_new_page
    @request.session[:user_id] = 2
    post :preview, :params => {
      :project_id => 1,
      :id => 'New page',
      :content => {
        :text => 'h1. New page',
        :comments => '',
        :version => 0
      }
    }, :xhr => true
    assert_response :success
    assert_select 'h1', :text => /New page/
  end

  def test_history
    @request.session[:user_id] = 2
    get :history, :params => {:project_id => 'ecookbook', :id => 'CookBook_documentation'}
    assert_response :success

    assert_select 'table.wiki-page-versions tbody' do
      assert_select 'tr', 3
    end

    assert_select "input[type=submit][name=commit]"
    assert_select 'td' do
      assert_select 'a[href=?]', '/projects/ecookbook/wiki/CookBook_documentation/2', :text => '2'
      assert_select 'a[href=?]', '/projects/ecookbook/wiki/CookBook_documentation/2/annotate', :text => 'Annotate'
      assert_select 'a[href=?]', '/projects/ecookbook/wiki/CookBook_documentation/2', :text => 'Delete'
    end
  end

  def test_history_with_one_version
    @request.session[:user_id] = 2
    get :history, :params => {:project_id => 'ecookbook', :id => 'Another_page'}
    assert_response :success

    assert_select 'table.wiki-page-versions tbody' do
      assert_select 'tr', 1
    end

    assert_select "input[type=submit][name=commit]", false
    assert_select 'td' do
      assert_select 'a[href=?]', '/projects/ecookbook/wiki/Another_page/1', :text => '1'
      assert_select 'a[href=?]', '/projects/ecookbook/wiki/Another_page/1/annotate', :text => 'Annotate'
      assert_select 'a[href=?]', '/projects/ecookbook/wiki/Another_page/1', :text => 'Delete', :count => 0
    end
  end

  def test_diff
    content = WikiPage.find(1).content
    assert_difference 'WikiContentVersion.count', 2 do
      content.text = "Line removed\nThis is a sample text for testing diffs"
      content.save!
      content.text = "This is a sample text for testing diffs\nLine added"
      content.save!
    end

    get :diff, :params => {
      :project_id => 1, :id => 'CookBook_documentation',
      :version => content.version,
      :version_from => (content.version - 1)
    }
    assert_response :success
    assert_select 'span.diff_out', :text => 'Line removed'
    assert_select 'span.diff_in', :text => 'Line added'
  end

  def test_diff_with_invalid_version_should_respond_with_404
    get :diff, :params => {
      :project_id => 1, :id => 'CookBook_documentation',
      :version => '99'
    }
    assert_response 404
  end

  def test_diff_with_invalid_version_from_should_respond_with_404
    get :diff, :params => {
      :project_id => 1, :id => 'CookBook_documentation',
      :version => '99',
      :version_from => '98'
    }
    assert_response 404
  end

  def test_annotate
    get :annotate, :params => {
      :project_id => 1, :id =>  'CookBook_documentation',
      :version => 2
    }
    assert_response :success

    # Line 1
    assert_select 'table.annotate tr:nth-child(1)' do
      assert_select 'th.line-num', :text => '1'
      assert_select 'td.author', :text => /Redmine Admin/
      assert_select 'td', :text => /h1\. CookBook documentation v2/
    end

    # Line 2
    assert_select 'table.annotate tr:nth-child(2)' do
      assert_select 'th.line-num', :text => '2'
      assert_select 'td.author', :text => /John Smith/
    end

    # Line 5
    assert_select 'table.annotate tr:nth-child(5)' do
      assert_select 'th.line-num', :text => '5'
      assert_select 'td.author', :text => /Redmine Admin/
      assert_select 'td', :text => /Some updated \[\[documentation\]\] here/
    end
  end

  def test_annotate_with_invalid_version_should_respond_with_404
    get :annotate, :params => {
      :project_id => 1, :id => 'CookBook_documentation',
      :version => '99'
    }
    assert_response 404
  end

  def test_get_rename
    @request.session[:user_id] = 2
    get :rename, :params => {:project_id => 1, :id => 'Another_page'}
    assert_response :success

    assert_select 'select[name=?]', 'wiki_page[parent_id]' do
      assert_select 'option[value=""]', :text => ''
      assert_select 'option[selected=selected]', 0
    end
  end

  def test_get_rename_child_page
    @request.session[:user_id] = 2
    get :rename, :params => {:project_id => 1, :id => 'Child_1'}
    assert_response :success

    assert_select 'select[name=?]', 'wiki_page[parent_id]' do
      assert_select 'option[value=""]', :text => ''
      assert_select 'option[value="2"][selected=selected]', :text => /Another page/
    end
  end

  def test_rename_with_redirect
    @request.session[:user_id] = 2
    post :rename, :params => {
      :project_id => 1,
      :id => 'Another_page',
      :wiki_page => {
        :title => 'Another renamed page',
        :redirect_existing_links => 1
      }
    }
    assert_redirected_to :action => 'show', :project_id => 'ecookbook', :id => 'Another_renamed_page'
    wiki = Project.find(1).wiki
    # Check redirects
    assert_not_nil wiki.find_page('Another page')
    assert_nil wiki.find_page('Another page', :with_redirect => false)
  end

  def test_rename_without_redirect
    @request.session[:user_id] = 2
    post :rename, :params => {
      :project_id => 1,
      :id => 'Another_page',
      :wiki_page => {
        :title => 'Another renamed page',
        :redirect_existing_links => "0"
      }
    }
    assert_redirected_to :action => 'show', :project_id => 'ecookbook', :id => 'Another_renamed_page'
    wiki = Project.find(1).wiki
    # Check that there's no redirects
    assert_nil wiki.find_page('Another page')
  end

  def test_rename_with_parent_assignment
    @request.session[:user_id] = 2
    post :rename, :params => {
      :project_id => 1,
      :id => 'Another_page',
      :wiki_page => {
        :title => 'Another page',
        :redirect_existing_links => "0",
        :parent_id => '4'
      }
    }
    assert_redirected_to :action => 'show', :project_id => 'ecookbook', :id => 'Another_page'
    assert_equal WikiPage.find(4), WikiPage.find_by_title('Another_page').parent
  end

  def test_rename_with_parent_unassignment
    @request.session[:user_id] = 2
    post :rename, :params => {
      :project_id => 1,
      :id => 'Child_1',
      :wiki_page => {
        :title => 'Child 1',
        :redirect_existing_links => "0",
        :parent_id => ''
      }
    }
    assert_redirected_to :action => 'show', :project_id => 'ecookbook', :id => 'Child_1'
    assert_nil WikiPage.find_by_title('Child_1').parent
  end

  def test_get_rename_should_show_target_projects_list
    @request.session[:user_id] = 2
    project = Project.find(5)
    project.enable_module! :wiki

    get :rename, :params => {:project_id => 1, :id => 'Another_page'}
    assert_response :success

    assert_select 'select[name=?]', 'wiki_page[wiki_id]' do
      assert_select 'option', 2
      assert_select 'option[value=?][selected=selected]', '1', :text => /eCookbook/
      assert_select 'option[value=?]', project.wiki.id.to_s, :text => /#{project.name}/
    end
  end

  def test_rename_with_move
    @request.session[:user_id] = 2
    project = Project.find(5)
    project.enable_module! :wiki

    post :rename, :params => {
      :project_id => 1,
      :id => 'Another_page',
      :wiki_page => {
        :wiki_id => project.wiki.id.to_s,
        :title => 'Another renamed page',
        :redirect_existing_links => 1
      }
    }
    assert_redirected_to '/projects/private-child/wiki/Another_renamed_page'

    page = WikiPage.find(2)
    assert_equal project.wiki.id, page.wiki_id
  end

  def test_rename_as_start_page
    @request.session[:user_id] = 2

    post :rename, :params => {
      :project_id => 'ecookbook',
      :id => 'Another_page',
      :wiki_page => {
        :wiki_id => '1',
        :title => 'Another_page',
        :redirect_existing_links => '1',
        :is_start_page => '1'
      }
    }
    assert_redirected_to '/projects/ecookbook/wiki/Another_page'

    wiki = Wiki.find(1)
    assert_equal 'Another_page', wiki.start_page
  end

  def test_destroy_a_page_without_children_should_not_ask_confirmation
    @request.session[:user_id] = 2
    delete :destroy, :params => {:project_id => 1, :id => 'Child_2'}
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
  end

  def test_destroy_parent_should_ask_confirmation
    @request.session[:user_id] = 2
    assert_no_difference('WikiPage.count') do
      delete :destroy, :params => {:project_id => 1, :id => 'Another_page'}
    end
    assert_response :success
    assert_select 'form' do
      assert_select 'input[name=todo][value=nullify]'
      assert_select 'input[name=todo][value=destroy]'
      assert_select 'input[name=todo][value=reassign]'
    end
  end

  def test_destroy_parent_with_nullify_should_delete_parent_only
    @request.session[:user_id] = 2
    assert_difference('WikiPage.count', -1) do
      delete :destroy, :params => {:project_id => 1, :id => 'Another_page', :todo => 'nullify'}
    end
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    assert_nil WikiPage.find_by_id(2)
  end

  def test_destroy_parent_with_cascade_should_delete_descendants
    @request.session[:user_id] = 2
    assert_difference('WikiPage.count', -4) do
      delete :destroy, :params => {:project_id => 1, :id => 'Another_page', :todo => 'destroy'}
    end
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    assert_nil WikiPage.find_by_id(2)
    assert_nil WikiPage.find_by_id(5)
  end

  def test_destroy_parent_with_reassign
    @request.session[:user_id] = 2
    assert_difference('WikiPage.count', -1) do
      delete :destroy, :params => {:project_id => 1, :id => 'Another_page', :todo => 'reassign', :reassign_to_id => 1}
    end
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    assert_nil WikiPage.find_by_id(2)
    assert_equal WikiPage.find(1), WikiPage.find_by_id(5).parent
  end

  def test_destroy_version
    @request.session[:user_id] = 2
    assert_difference 'WikiContentVersion.count', -1 do
      assert_no_difference 'WikiContent.count' do
        assert_no_difference 'WikiPage.count' do
          delete :destroy_version, :params => {:project_id => 'ecookbook', :id => 'CookBook_documentation', :version => 2}
          assert_redirected_to '/projects/ecookbook/wiki/CookBook_documentation/history'
        end
      end
    end
  end

  def test_destroy_invalid_version_should_respond_with_404
    @request.session[:user_id] = 2
    assert_no_difference 'WikiContentVersion.count' do
      assert_no_difference 'WikiContent.count' do
        assert_no_difference 'WikiPage.count' do
          delete :destroy_version, :params => {:project_id => 'ecookbook', :id => 'CookBook_documentation', :version => 99}
        end
      end
    end
    assert_response 404
  end

  def test_index
    get :index, :params => {:project_id => 'ecookbook'}
    assert_response :success

    assert_select 'ul.pages-hierarchy' do
      assert_select 'li', Project.find(1).wiki.pages.count
    end

    assert_select 'ul.pages-hierarchy' do
      assert_select 'li' do
        assert_select 'a[href=?]', '/projects/ecookbook/wiki/CookBook_documentation', :text => 'CookBook documentation'
        assert_select 'ul li a[href=?]', '/projects/ecookbook/wiki/Page_with_an_inline_image', :text => 'Page with an inline image'
      end
      assert_select 'li a[href=?]', '/projects/ecookbook/wiki/Another_page', :text => 'Another page'
    end
  end

  def test_index_should_include_atom_link
    get :index, :params => {:project_id => 'ecookbook'}
    assert_select 'a[href=?]', '/projects/ecookbook/activity.atom?show_wiki_edits=1'
  end

  def test_export_to_html
    @request.session[:user_id] = 2
    get :export, :params => {:project_id => 'ecookbook'}

    assert_response :success
    assert_equal "text/html", @response.content_type

    assert_select "a[name=?]", "CookBook_documentation"
    assert_select "a[name=?]", "Another_page"
    assert_select "a[name=?]", "Page_with_an_inline_image"
  end

  def test_export_to_pdf
    @request.session[:user_id] = 2
    get :export, :params => {:project_id => 'ecookbook', :format => 'pdf'}

    assert_response :success
    assert_equal 'application/pdf', @response.content_type
    assert_equal 'attachment; filename="ecookbook.pdf"', @response.headers['Content-Disposition']
    assert @response.body.starts_with?('%PDF')
  end

  def test_export_without_permission_should_be_denied
    @request.session[:user_id] = 2
    Role.find_by_name('Manager').remove_permission! :export_wiki_pages
    get :export, :params => {:project_id => 'ecookbook'}

    assert_response 403
  end

  def test_date_index
    get :date_index, :params => {:project_id => 'ecookbook'}

    assert_response :success

    assert_select 'a[href=?]', '/projects/ecookbook/activity.atom?show_wiki_edits=1'
  end

  def test_not_found
    get :show, :params => {:project_id => 999}
    assert_response 404
  end

  def test_protect_page
    page = WikiPage.find_by_wiki_id_and_title(1, 'Another_page')
    assert !page.protected?
    @request.session[:user_id] = 2
    post :protect, :params => {:project_id => 1, :id => page.title, :protected => '1'}
    assert_redirected_to :action => 'show', :project_id => 'ecookbook', :id => 'Another_page'
    assert page.reload.protected?
  end

  def test_unprotect_page
    page = WikiPage.find_by_wiki_id_and_title(1, 'CookBook_documentation')
    assert page.protected?
    @request.session[:user_id] = 2
    post :protect, :params => {:project_id => 1, :id => page.title, :protected => '0'}
    assert_redirected_to :action => 'show', :project_id => 'ecookbook', :id => 'CookBook_documentation'
    assert !page.reload.protected?
  end

  def test_show_page_with_edit_link
    @request.session[:user_id] = 2
    get :show, :params => {:project_id => 1}
    assert_response :success

    assert_select 'a[href=?]', '/projects/1/wiki/CookBook_documentation/edit'
  end

  def test_show_page_without_edit_link
    @request.session[:user_id] = 4
    get :show, :params => {:project_id => 1}
    assert_response :success

    assert_select 'a[href=?]', '/projects/1/wiki/CookBook_documentation/edit', 0
  end

  def test_show_pdf
    @request.session[:user_id] = 2
    get :show, :params => {:project_id => 1, :format => 'pdf'}
    assert_response :success

    assert_equal 'application/pdf', @response.content_type
    assert_equal 'attachment; filename="CookBook_documentation.pdf"',
                  @response.headers['Content-Disposition']
  end

  def test_show_html
    @request.session[:user_id] = 2
    get :show, :params => {:project_id => 1, :format => 'html'}
    assert_response :success

    assert_equal 'text/html', @response.content_type
    assert_equal 'attachment; filename="CookBook_documentation.html"',
                  @response.headers['Content-Disposition']
    assert_select 'h1', :text => /CookBook documentation/
  end

  def test_show_versioned_html
    @request.session[:user_id] = 2
    get :show, :params => {:project_id => 1, :format => 'html', :version => 2}
    assert_response :success

    assert_equal 'text/html', @response.content_type
    assert_equal 'attachment; filename="CookBook_documentation.html"',
                  @response.headers['Content-Disposition']
    assert_select 'h1', :text => /CookBook documentation v2/
  end

  def test_show_txt
    @request.session[:user_id] = 2
    get :show, :params => {:project_id => 1, :format => 'txt'}
    assert_response :success

    assert_equal 'text/plain', @response.content_type
    assert_equal 'attachment; filename="CookBook_documentation.txt"',
                  @response.headers['Content-Disposition']
    assert_include 'h1. CookBook documentation', @response.body
  end

  def test_show_versioned_txt
    @request.session[:user_id] = 2
    get :show, :params => {:project_id => 1, :format => 'txt', :version => 2}
    assert_response :success

    assert_equal 'text/plain', @response.content_type
    assert_equal 'attachment; filename="CookBook_documentation.txt"',
                  @response.headers['Content-Disposition']
    assert_include 'h1. CookBook documentation v2', @response.body
  end

  def test_show_filename_should_be_uri_encoded_for_ms_browsers
    @request.session[:user_id] = 2
    title = 'Этика_менеджмента'
    %w|pdf html txt|.each do |format|
      # Non-MS browsers
      @request.user_agent = ""
      get :show, :params => {:project_id => 1, :id => title, :format => format}
      assert_response :success
      assert_equal "attachment; filename=\"#{title}.#{format}\"",
                    @response.headers['Content-Disposition']
      # Microsoft's browsers: filename should be URI encoded
      @request.user_agent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/52.0.2743.116 Safari/537.36 Edge/15.15063'
      get :show, :params => {:project_id => 1, :id => title, :format => format}
      assert_response :success
      filename = URI.encode("#{title}.#{format}")
      assert_equal "attachment; filename=\"#{filename}\"",
                    @response.headers['Content-Disposition']
    end
  end

  def test_edit_unprotected_page
    # Non members can edit unprotected wiki pages
    @request.session[:user_id] = 4
    get :edit, :params => {:project_id => 1, :id => 'Another_page'}
    assert_response :success
  end

  def test_edit_protected_page_by_nonmember
    # Non members cannot edit protected wiki pages
    @request.session[:user_id] = 4
    get :edit, :params => {:project_id => 1, :id => 'CookBook_documentation'}
    assert_response 403
  end

  def test_edit_protected_page_by_member
    @request.session[:user_id] = 2
    get :edit, :params => {:project_id => 1, :id => 'CookBook_documentation'}
    assert_response :success
  end

  def test_history_of_non_existing_page_should_return_404
    get :history, :params => {:project_id => 1, :id => 'Unknown_page'}
    assert_response 404
  end

  def test_add_attachment
    @request.session[:user_id] = 2
    assert_difference 'Attachment.count' do
      post :add_attachment, :params => {
        :project_id => 1,
        :id => 'CookBook_documentation',
        :attachments => {
          '1' => {'file' => uploaded_test_file('testfile.txt', 'text/plain'), 'description' => 'test file'}
        }
      }
    end
    attachment = Attachment.order('id DESC').first
    assert_equal Wiki.find(1).find_page('CookBook_documentation'), attachment.container
  end

  def test_old_version_should_have_robot_exclusion_tag
    @request.session[:user_id] = 2
    # Discourage search engines from indexing old versions
    get :show, :params => {:project_id => 'ecookbook', :id => 'CookBook_documentation', :version => '2'}
    assert_response :success
    assert_select 'head>meta[name="robots"][content=?]', 'noindex,follow,noarchive'

    # No robots meta tag in the current version
    get :show, :params => {:project_id => 'ecookbook', :id => 'CookBook_documentation'}
    assert_response :success
    assert_select 'head>meta[name="robots"]', false
  end
end
