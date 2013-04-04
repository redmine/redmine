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

class WikiControllerTest < ActionController::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles,
           :enabled_modules, :wikis, :wiki_pages, :wiki_contents,
           :wiki_content_versions, :attachments

  def setup
    User.current = nil
  end

  def test_show_start_page
    get :show, :project_id => 'ecookbook'
    assert_response :success
    assert_template 'show'
    assert_tag :tag => 'h1', :content => /CookBook documentation/

    # child_pages macro
    assert_tag :ul, :attributes => { :class => 'pages-hierarchy' },
               :child => { :tag => 'li',
                           :child => { :tag => 'a', :attributes => { :href => '/projects/ecookbook/wiki/Page_with_an_inline_image' },
                                                    :content => 'Page with an inline image' } }
  end
  
  def test_export_link
    Role.anonymous.add_permission! :export_wiki_pages
    get :show, :project_id => 'ecookbook'
    assert_response :success
    assert_tag 'a', :attributes => {:href => '/projects/ecookbook/wiki/CookBook_documentation.txt'}
  end

  def test_show_page_with_name
    get :show, :project_id => 1, :id => 'Another_page'
    assert_response :success
    assert_template 'show'
    assert_tag :tag => 'h1', :content => /Another page/
    # Included page with an inline image
    assert_tag :tag => 'p', :content => /This is an inline image/
    assert_tag :tag => 'img', :attributes => { :src => '/attachments/download/3/logo.gif',
                                               :alt => 'This is a logo' }
  end

  def test_show_old_version
    get :show, :project_id => 'ecookbook', :id => 'CookBook_documentation', :version => '2'
    assert_response :success
    assert_template 'show'

    assert_select 'a[href=?]', '/projects/ecookbook/wiki/CookBook_documentation/1', :text => /Previous/
    assert_select 'a[href=?]', '/projects/ecookbook/wiki/CookBook_documentation/2/diff', :text => /diff/
    assert_select 'a[href=?]', '/projects/ecookbook/wiki/CookBook_documentation/3', :text => /Next/
    assert_select 'a[href=?]', '/projects/ecookbook/wiki/CookBook_documentation', :text => /Current version/
  end

  def test_show_old_version_with_attachments
    page = WikiPage.find(4)
    assert page.attachments.any?
    content = page.content
    content.text = "update"
    content.save!

    get :show, :project_id => 'ecookbook', :id => page.title, :version => '1'
    assert_kind_of WikiContent::Version, assigns(:content)
    assert_response :success
    assert_template 'show'
  end

  def test_show_old_version_without_permission_should_be_denied
    Role.anonymous.remove_permission! :view_wiki_edits

    get :show, :project_id => 'ecookbook', :id => 'CookBook_documentation', :version => '2'
    assert_redirected_to '/login?back_url=http%3A%2F%2Ftest.host%2Fprojects%2Fecookbook%2Fwiki%2FCookBook_documentation%2F2'
  end

  def test_show_first_version
    get :show, :project_id => 'ecookbook', :id => 'CookBook_documentation', :version => '1'
    assert_response :success
    assert_template 'show'

    assert_select 'a', :text => /Previous/, :count => 0
    assert_select 'a', :text => /diff/, :count => 0
    assert_select 'a[href=?]', '/projects/ecookbook/wiki/CookBook_documentation/2', :text => /Next/
    assert_select 'a[href=?]', '/projects/ecookbook/wiki/CookBook_documentation', :text => /Current version/
  end

  def test_show_redirected_page
    WikiRedirect.create!(:wiki_id => 1, :title => 'Old_title', :redirects_to => 'Another_page')

    get :show, :project_id => 'ecookbook', :id => 'Old_title'
    assert_redirected_to '/projects/ecookbook/wiki/Another_page'
  end

  def test_show_with_sidebar
    page = Project.find(1).wiki.pages.new(:title => 'Sidebar')
    page.content = WikiContent.new(:text => 'Side bar content for test_show_with_sidebar')
    page.save!

    get :show, :project_id => 1, :id => 'Another_page'
    assert_response :success
    assert_tag :tag => 'div', :attributes => {:id => 'sidebar'},
                              :content => /Side bar content for test_show_with_sidebar/
  end
  
  def test_show_should_display_section_edit_links
    @request.session[:user_id] = 2
    get :show, :project_id => 1, :id => 'Page with sections'
    assert_no_tag 'a', :attributes => {
      :href => '/projects/ecookbook/wiki/Page_with_sections/edit?section=1'
    }
    assert_tag 'a', :attributes => {
      :href => '/projects/ecookbook/wiki/Page_with_sections/edit?section=2'
    }
    assert_tag 'a', :attributes => {
      :href => '/projects/ecookbook/wiki/Page_with_sections/edit?section=3'
    }
  end

  def test_show_current_version_should_display_section_edit_links
    @request.session[:user_id] = 2
    get :show, :project_id => 1, :id => 'Page with sections', :version => 3

    assert_tag 'a', :attributes => {
      :href => '/projects/ecookbook/wiki/Page_with_sections/edit?section=2'
    }
  end

  def test_show_old_version_should_not_display_section_edit_links
    @request.session[:user_id] = 2
    get :show, :project_id => 1, :id => 'Page with sections', :version => 2

    assert_no_tag 'a', :attributes => {
      :href => '/projects/ecookbook/wiki/Page_with_sections/edit?section=2'
    }
  end

  def test_show_unexistent_page_without_edit_right
    get :show, :project_id => 1, :id => 'Unexistent page'
    assert_response 404
  end

  def test_show_unexistent_page_with_edit_right
    @request.session[:user_id] = 2
    get :show, :project_id => 1, :id => 'Unexistent page'
    assert_response :success
    assert_template 'edit'
  end

  def test_show_unexistent_page_with_parent_should_preselect_parent
    @request.session[:user_id] = 2
    get :show, :project_id => 1, :id => 'Unexistent page', :parent => 'Another_page'
    assert_response :success
    assert_template 'edit'
    assert_tag 'select', :attributes => {:name => 'wiki_page[parent_id]'},
      :child => {:tag => 'option', :attributes => {:value => '2', :selected => 'selected'}}
  end

  def test_show_should_not_show_history_without_permission
    Role.anonymous.remove_permission! :view_wiki_edits
    get :show, :project_id => 1, :id => 'Page with sections', :version => 2

    assert_response 302
  end

  def test_create_page
    @request.session[:user_id] = 2
    assert_difference 'WikiPage.count' do
      assert_difference 'WikiContent.count' do
        put :update, :project_id => 1,
                    :id => 'New page',
                    :content => {:comments => 'Created the page',
                                 :text => "h1. New page\n\nThis is a new page",
                                 :version => 0}
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
        put :update, :project_id => 1,
                    :id => 'New page',
                    :content => {:comments => 'Created the page',
                                 :text => "h1. New page\n\nThis is a new page",
                                 :version => 0},
                    :attachments => {'1' => {'file' => uploaded_test_file('testfile.txt', 'text/plain')}}
      end
    end
    page = Project.find(1).wiki.find_page('New page')
    assert_equal 1, page.attachments.count
    assert_equal 'testfile.txt', page.attachments.first.filename
  end

  def test_create_page_with_parent
    @request.session[:user_id] = 2
    assert_difference 'WikiPage.count' do
      put :update, :project_id => 1, :id => 'New page',
        :content => {:text => "h1. New page\n\nThis is a new page", :version => 0},
        :wiki_page => {:parent_id => 2}
    end
    page = Project.find(1).wiki.find_page('New page')
    assert_equal WikiPage.find(2), page.parent
  end

  def test_edit_page
    @request.session[:user_id] = 2
    get :edit, :project_id => 'ecookbook', :id => 'Another_page'

    assert_response :success
    assert_template 'edit'

    assert_tag 'textarea',
      :attributes => { :name => 'content[text]' },
      :content => "\n"+WikiPage.find_by_title('Another_page').content.text
  end

  def test_edit_section
    @request.session[:user_id] = 2
    get :edit, :project_id => 'ecookbook', :id => 'Page_with_sections', :section => 2

    assert_response :success
    assert_template 'edit'
    
    page = WikiPage.find_by_title('Page_with_sections')
    section, hash = Redmine::WikiFormatting::Textile::Formatter.new(page.content.text).get_section(2)

    assert_tag 'textarea',
      :attributes => { :name => 'content[text]' },
      :content => "\n"+section
    assert_tag 'input',
      :attributes => { :name => 'section', :type => 'hidden', :value => '2' }
    assert_tag 'input',
      :attributes => { :name => 'section_hash', :type => 'hidden', :value => hash }
  end

  def test_edit_invalid_section_should_respond_with_404
    @request.session[:user_id] = 2
    get :edit, :project_id => 'ecookbook', :id => 'Page_with_sections', :section => 10

    assert_response 404
  end

  def test_update_page
    @request.session[:user_id] = 2
    assert_no_difference 'WikiPage.count' do
      assert_no_difference 'WikiContent.count' do
        assert_difference 'WikiContent::Version.count' do
          put :update, :project_id => 1,
            :id => 'Another_page',
            :content => {
              :comments => "my comments",
              :text => "edited",
              :version => 1
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
        assert_difference 'WikiContent::Version.count' do
          put :update, :project_id => 1,
            :id => 'Another_page',
            :content => {
              :comments => "my comments",
              :text => "edited",
              :version => 1
            },
            :wiki_page => {:parent_id => '1'}
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
        assert_no_difference 'WikiContent::Version.count' do
          put :update, :project_id => 1,
            :id => 'Another_page',
            :content => {
              :comments => 'a' * 300,  # failure here, comment is too long
              :text => 'edited',
              :version => 1
            }
          end
        end
      end
    assert_response :success
    assert_template 'edit'

    assert_error_tag :descendant => {:content => /Comment is too long/}
    assert_tag :tag => 'textarea', :attributes => {:id => 'content_text'}, :content => "\nedited"
    assert_tag :tag => 'input', :attributes => {:id => 'content_version', :value => '1'}
  end

  def test_update_page_with_parent_change_only_should_not_create_content_version
    @request.session[:user_id] = 2
    assert_no_difference 'WikiPage.count' do
      assert_no_difference 'WikiContent.count' do
        assert_no_difference 'WikiContent::Version.count' do
          put :update, :project_id => 1,
            :id => 'Another_page',
            :content => {
              :comments => '',
              :text => Wiki.find(1).find_page('Another_page').content.text,
              :version => 1
            },
            :wiki_page => {:parent_id => '1'}
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
        assert_no_difference 'WikiContent::Version.count' do
          assert_difference 'Attachment.count' do
            put :update, :project_id => 1,
              :id => 'Another_page',
              :content => {
                :comments => '',
                :text => Wiki.find(1).find_page('Another_page').content.text,
                :version => 1
              },
              :attachments => {'1' => {'file' => uploaded_test_file('testfile.txt', 'text/plain'), 'description' => 'test file'}}
          end
        end
      end
    end
    page = Wiki.find(1).pages.find_by_title('Another_page')
    assert_equal 1, page.content.version
  end

  def test_update_stale_page_should_not_raise_an_error
    @request.session[:user_id] = 2
    c = Wiki.find(1).find_page('Another_page').content
    c.text = 'Previous text'
    c.save!
    assert_equal 2, c.version

    assert_no_difference 'WikiPage.count' do
      assert_no_difference 'WikiContent.count' do
        assert_no_difference 'WikiContent::Version.count' do
          put :update, :project_id => 1,
            :id => 'Another_page',
            :content => {
              :comments => 'My comments',
              :text => 'Text should not be lost',
              :version => 1
            }
        end
      end
    end
    assert_response :success
    assert_template 'edit'
    assert_tag :div,
      :attributes => { :class => /error/ },
      :content => /Data has been updated by another user/
    assert_tag 'textarea',
      :attributes => { :name => 'content[text]' },
      :content => /Text should not be lost/
    assert_tag 'input',
      :attributes => { :name => 'content[comments]', :value => 'My comments' }

    c.reload
    assert_equal 'Previous text', c.text
    assert_equal 2, c.version
  end

  def test_update_section
    @request.session[:user_id] = 2
    page = WikiPage.find_by_title('Page_with_sections')
    section, hash = Redmine::WikiFormatting::Textile::Formatter.new(page.content.text).get_section(2)
    text = page.content.text

    assert_no_difference 'WikiPage.count' do
      assert_no_difference 'WikiContent.count' do
        assert_difference 'WikiContent::Version.count' do
          put :update, :project_id => 1, :id => 'Page_with_sections',
            :content => {
              :text => "New section content",
              :version => 3
            },
            :section => 2,
            :section_hash => hash
        end
      end
    end
    assert_redirected_to '/projects/ecookbook/wiki/Page_with_sections'
    assert_equal Redmine::WikiFormatting::Textile::Formatter.new(text).update_section(2, "New section content"), page.reload.content.text
  end

  def test_update_section_should_allow_stale_page_update
    @request.session[:user_id] = 2
    page = WikiPage.find_by_title('Page_with_sections')
    section, hash = Redmine::WikiFormatting::Textile::Formatter.new(page.content.text).get_section(2)
    text = page.content.text

    assert_no_difference 'WikiPage.count' do
      assert_no_difference 'WikiContent.count' do
        assert_difference 'WikiContent::Version.count' do
          put :update, :project_id => 1, :id => 'Page_with_sections',
            :content => {
              :text => "New section content",
              :version => 2 # Current version is 3
            },
            :section => 2,
            :section_hash => hash
        end
      end
    end
    assert_redirected_to '/projects/ecookbook/wiki/Page_with_sections'
    page.reload
    assert_equal Redmine::WikiFormatting::Textile::Formatter.new(text).update_section(2, "New section content"), page.content.text
    assert_equal 4, page.content.version
  end

  def test_update_section_should_not_allow_stale_section_update
    @request.session[:user_id] = 2

    assert_no_difference 'WikiPage.count' do
      assert_no_difference 'WikiContent.count' do
        assert_no_difference 'WikiContent::Version.count' do
          put :update, :project_id => 1, :id => 'Page_with_sections',
            :content => {
              :comments => 'My comments',
              :text => "Text should not be lost",
              :version => 3
            },
            :section => 2,
            :section_hash => Digest::MD5.hexdigest("wrong hash")
        end
      end
    end
    assert_response :success
    assert_template 'edit'
    assert_tag :div,
      :attributes => { :class => /error/ },
      :content => /Data has been updated by another user/
    assert_tag 'textarea',
      :attributes => { :name => 'content[text]' },
      :content => /Text should not be lost/
    assert_tag 'input',
      :attributes => { :name => 'content[comments]', :value => 'My comments' }
  end

  def test_preview
    @request.session[:user_id] = 2
    xhr :post, :preview, :project_id => 1, :id => 'CookBook_documentation',
                                   :content => { :comments => '',
                                                 :text => 'this is a *previewed text*',
                                                 :version => 3 }
    assert_response :success
    assert_template 'common/_preview'
    assert_tag :tag => 'strong', :content => /previewed text/
  end

  def test_preview_new_page
    @request.session[:user_id] = 2
    xhr :post, :preview, :project_id => 1, :id => 'New page',
                                   :content => { :text => 'h1. New page',
                                                 :comments => '',
                                                 :version => 0 }
    assert_response :success
    assert_template 'common/_preview'
    assert_tag :tag => 'h1', :content => /New page/
  end

  def test_history
    @request.session[:user_id] = 2
    get :history, :project_id => 'ecookbook', :id => 'CookBook_documentation'
    assert_response :success
    assert_template 'history'
    assert_not_nil assigns(:versions)
    assert_equal 3, assigns(:versions).size

    assert_select "input[type=submit][name=commit]"
    assert_select 'td' do
      assert_select 'a[href=?]', '/projects/ecookbook/wiki/CookBook_documentation/2', :text => '2'
      assert_select 'a[href=?]', '/projects/ecookbook/wiki/CookBook_documentation/2/annotate', :text => 'Annotate'
      assert_select 'a[href=?]', '/projects/ecookbook/wiki/CookBook_documentation/2', :text => 'Delete'
    end
  end

  def test_history_with_one_version
    @request.session[:user_id] = 2
    get :history, :project_id => 'ecookbook', :id => 'Another_page'
    assert_response :success
    assert_template 'history'
    assert_not_nil assigns(:versions)
    assert_equal 1, assigns(:versions).size
    assert_select "input[type=submit][name=commit]", false
    assert_select 'td' do
      assert_select 'a[href=?]', '/projects/ecookbook/wiki/Another_page/1', :text => '1'
      assert_select 'a[href=?]', '/projects/ecookbook/wiki/Another_page/1/annotate', :text => 'Annotate'
      assert_select 'a[href=?]', '/projects/ecookbook/wiki/Another_page/1', :text => 'Delete', :count => 0
    end
  end

  def test_diff
    content = WikiPage.find(1).content
    assert_difference 'WikiContent::Version.count', 2 do
      content.text = "Line removed\nThis is a sample text for testing diffs"
      content.save!
      content.text = "This is a sample text for testing diffs\nLine added"
      content.save!
    end

    get :diff, :project_id => 1, :id => 'CookBook_documentation', :version => content.version, :version_from => (content.version - 1)
    assert_response :success
    assert_template 'diff'
    assert_select 'span.diff_out', :text => 'Line removed'
    assert_select 'span.diff_in', :text => 'Line added'
  end

  def test_diff_with_invalid_version_should_respond_with_404
    get :diff, :project_id => 1, :id => 'CookBook_documentation', :version => '99'
    assert_response 404
  end

  def test_diff_with_invalid_version_from_should_respond_with_404
    get :diff, :project_id => 1, :id => 'CookBook_documentation', :version => '99', :version_from => '98'
    assert_response 404
  end

  def test_annotate
    get :annotate, :project_id => 1, :id =>  'CookBook_documentation', :version => 2
    assert_response :success
    assert_template 'annotate'

    # Line 1
    assert_tag :tag => 'tr', :child => {
      :tag => 'th', :attributes => {:class => 'line-num'}, :content => '1', :sibling => {
        :tag => 'td', :attributes => {:class => 'author'}, :content => /John Smith/, :sibling => {
          :tag => 'td', :content => /h1\. CookBook documentation/
        }
      }
    }

    # Line 5
    assert_tag :tag => 'tr', :child => {
      :tag => 'th', :attributes => {:class => 'line-num'}, :content => '5', :sibling => {
        :tag => 'td', :attributes => {:class => 'author'}, :content => /Redmine Admin/, :sibling => {
          :tag => 'td', :content => /Some updated \[\[documentation\]\] here/
        }
      }
    }
  end

  def test_annotate_with_invalid_version_should_respond_with_404
    get :annotate, :project_id => 1, :id => 'CookBook_documentation', :version => '99'
    assert_response 404
  end

  def test_get_rename
    @request.session[:user_id] = 2
    get :rename, :project_id => 1, :id => 'Another_page'
    assert_response :success
    assert_template 'rename'
    assert_tag 'option',
      :attributes => {:value => ''},
      :content => '',
      :parent => {:tag => 'select', :attributes => {:name => 'wiki_page[parent_id]'}}
    assert_no_tag 'option',
      :attributes => {:selected => 'selected'},
      :parent => {:tag => 'select', :attributes => {:name => 'wiki_page[parent_id]'}}
  end

  def test_get_rename_child_page
    @request.session[:user_id] = 2
    get :rename, :project_id => 1, :id => 'Child_1'
    assert_response :success
    assert_template 'rename'
    assert_tag 'option',
      :attributes => {:value => ''},
      :content => '',
      :parent => {:tag => 'select', :attributes => {:name => 'wiki_page[parent_id]'}}
    assert_tag 'option',
      :attributes => {:value => '2', :selected => 'selected'},
      :content => /Another page/,
      :parent => {
        :tag => 'select',
        :attributes => {:name => 'wiki_page[parent_id]'}
      }
  end

  def test_rename_with_redirect
    @request.session[:user_id] = 2
    post :rename, :project_id => 1, :id => 'Another_page',
                            :wiki_page => { :title => 'Another renamed page',
                                            :redirect_existing_links => 1 }
    assert_redirected_to :action => 'show', :project_id => 'ecookbook', :id => 'Another_renamed_page'
    wiki = Project.find(1).wiki
    # Check redirects
    assert_not_nil wiki.find_page('Another page')
    assert_nil wiki.find_page('Another page', :with_redirect => false)
  end

  def test_rename_without_redirect
    @request.session[:user_id] = 2
    post :rename, :project_id => 1, :id => 'Another_page',
                            :wiki_page => { :title => 'Another renamed page',
                                            :redirect_existing_links => "0" }
    assert_redirected_to :action => 'show', :project_id => 'ecookbook', :id => 'Another_renamed_page'
    wiki = Project.find(1).wiki
    # Check that there's no redirects
    assert_nil wiki.find_page('Another page')
  end

  def test_rename_with_parent_assignment
    @request.session[:user_id] = 2
    post :rename, :project_id => 1, :id => 'Another_page',
      :wiki_page => { :title => 'Another page', :redirect_existing_links => "0", :parent_id => '4' }
    assert_redirected_to :action => 'show', :project_id => 'ecookbook', :id => 'Another_page'
    assert_equal WikiPage.find(4), WikiPage.find_by_title('Another_page').parent
  end

  def test_rename_with_parent_unassignment
    @request.session[:user_id] = 2
    post :rename, :project_id => 1, :id => 'Child_1',
      :wiki_page => { :title => 'Child 1', :redirect_existing_links => "0", :parent_id => '' }
    assert_redirected_to :action => 'show', :project_id => 'ecookbook', :id => 'Child_1'
    assert_nil WikiPage.find_by_title('Child_1').parent
  end

  def test_destroy_a_page_without_children_should_not_ask_confirmation
    @request.session[:user_id] = 2
    delete :destroy, :project_id => 1, :id => 'Child_2'
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
  end

  def test_destroy_parent_should_ask_confirmation
    @request.session[:user_id] = 2
    assert_no_difference('WikiPage.count') do
      delete :destroy, :project_id => 1, :id => 'Another_page'
    end
    assert_response :success
    assert_template 'destroy'
    assert_select 'form' do
      assert_select 'input[name=todo][value=nullify]'
      assert_select 'input[name=todo][value=destroy]'
      assert_select 'input[name=todo][value=reassign]'
    end
  end

  def test_destroy_parent_with_nullify_should_delete_parent_only
    @request.session[:user_id] = 2
    assert_difference('WikiPage.count', -1) do
      delete :destroy, :project_id => 1, :id => 'Another_page', :todo => 'nullify'
    end
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    assert_nil WikiPage.find_by_id(2)
  end

  def test_destroy_parent_with_cascade_should_delete_descendants
    @request.session[:user_id] = 2
    assert_difference('WikiPage.count', -4) do
      delete :destroy, :project_id => 1, :id => 'Another_page', :todo => 'destroy'
    end
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    assert_nil WikiPage.find_by_id(2)
    assert_nil WikiPage.find_by_id(5)
  end

  def test_destroy_parent_with_reassign
    @request.session[:user_id] = 2
    assert_difference('WikiPage.count', -1) do
      delete :destroy, :project_id => 1, :id => 'Another_page', :todo => 'reassign', :reassign_to_id => 1
    end
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    assert_nil WikiPage.find_by_id(2)
    assert_equal WikiPage.find(1), WikiPage.find_by_id(5).parent
  end

  def test_destroy_version
    @request.session[:user_id] = 2
    assert_difference 'WikiContent::Version.count', -1 do
      assert_no_difference 'WikiContent.count' do
        assert_no_difference 'WikiPage.count' do
          delete :destroy_version, :project_id => 'ecookbook', :id => 'CookBook_documentation', :version => 2
          assert_redirected_to '/projects/ecookbook/wiki/CookBook_documentation/history'
        end
      end
    end
  end

  def test_index
    get :index, :project_id => 'ecookbook'
    assert_response :success
    assert_template 'index'
    pages = assigns(:pages)
    assert_not_nil pages
    assert_equal Project.find(1).wiki.pages.size, pages.size
    assert_equal pages.first.content.updated_on, pages.first.updated_on

    assert_tag :ul, :attributes => { :class => 'pages-hierarchy' },
                    :child => { :tag => 'li', :child => { :tag => 'a', :attributes => { :href => '/projects/ecookbook/wiki/CookBook_documentation' },
                                              :content => 'CookBook documentation' },
                                :child => { :tag => 'ul',
                                            :child => { :tag => 'li',
                                                        :child => { :tag => 'a', :attributes => { :href => '/projects/ecookbook/wiki/Page_with_an_inline_image' },
                                                                                 :content => 'Page with an inline image' } } } },
                    :child => { :tag => 'li', :child => { :tag => 'a', :attributes => { :href => '/projects/ecookbook/wiki/Another_page' },
                                                                       :content => 'Another page' } }
  end

  def test_index_should_include_atom_link
    get :index, :project_id => 'ecookbook'
    assert_tag 'a', :attributes => { :href => '/projects/ecookbook/activity.atom?show_wiki_edits=1'}
  end

  def test_export_to_html
    @request.session[:user_id] = 2
    get :export, :project_id => 'ecookbook'

    assert_response :success
    assert_not_nil assigns(:pages)
    assert assigns(:pages).any?
    assert_equal "text/html", @response.content_type

    assert_select "a[name=?]", "CookBook_documentation"
    assert_select "a[name=?]", "Another_page"
    assert_select "a[name=?]", "Page_with_an_inline_image"
  end

  def test_export_to_pdf
    @request.session[:user_id] = 2
    get :export, :project_id => 'ecookbook', :format => 'pdf'

    assert_response :success
    assert_not_nil assigns(:pages)
    assert assigns(:pages).any?
    assert_equal 'application/pdf', @response.content_type
    assert_equal 'attachment; filename="ecookbook.pdf"', @response.headers['Content-Disposition']
    assert @response.body.starts_with?('%PDF')
  end

  def test_export_without_permission_should_be_denied
    @request.session[:user_id] = 2
    Role.find_by_name('Manager').remove_permission! :export_wiki_pages
    get :export, :project_id => 'ecookbook'

    assert_response 403
  end

  def test_date_index
    get :date_index, :project_id => 'ecookbook'

    assert_response :success
    assert_template 'date_index'
    assert_not_nil assigns(:pages)
    assert_not_nil assigns(:pages_by_date)

    assert_tag 'a', :attributes => { :href => '/projects/ecookbook/activity.atom?show_wiki_edits=1'}
  end

  def test_not_found
    get :show, :project_id => 999
    assert_response 404
  end

  def test_protect_page
    page = WikiPage.find_by_wiki_id_and_title(1, 'Another_page')
    assert !page.protected?
    @request.session[:user_id] = 2
    post :protect, :project_id => 1, :id => page.title, :protected => '1'
    assert_redirected_to :action => 'show', :project_id => 'ecookbook', :id => 'Another_page'
    assert page.reload.protected?
  end

  def test_unprotect_page
    page = WikiPage.find_by_wiki_id_and_title(1, 'CookBook_documentation')
    assert page.protected?
    @request.session[:user_id] = 2
    post :protect, :project_id => 1, :id => page.title, :protected => '0'
    assert_redirected_to :action => 'show', :project_id => 'ecookbook', :id => 'CookBook_documentation'
    assert !page.reload.protected?
  end

  def test_show_page_with_edit_link
    @request.session[:user_id] = 2
    get :show, :project_id => 1
    assert_response :success
    assert_template 'show'
    assert_tag :tag => 'a', :attributes => { :href => '/projects/1/wiki/CookBook_documentation/edit' }
  end

  def test_show_page_without_edit_link
    @request.session[:user_id] = 4
    get :show, :project_id => 1
    assert_response :success
    assert_template 'show'
    assert_no_tag :tag => 'a', :attributes => { :href => '/projects/1/wiki/CookBook_documentation/edit' }
  end

  def test_show_pdf
    @request.session[:user_id] = 2
    get :show, :project_id => 1, :format => 'pdf'
    assert_response :success
    assert_not_nil assigns(:page)
    assert_equal 'application/pdf', @response.content_type
    assert_equal 'attachment; filename="CookBook_documentation.pdf"',
                  @response.headers['Content-Disposition']
  end

  def test_show_html
    @request.session[:user_id] = 2
    get :show, :project_id => 1, :format => 'html'
    assert_response :success
    assert_not_nil assigns(:page)
    assert_equal 'text/html', @response.content_type
    assert_equal 'attachment; filename="CookBook_documentation.html"',
                  @response.headers['Content-Disposition']
    assert_tag 'h1', :content => 'CookBook documentation'
  end

  def test_show_versioned_html
    @request.session[:user_id] = 2
    get :show, :project_id => 1, :format => 'html', :version => 2
    assert_response :success
    assert_not_nil assigns(:content)
    assert_equal 2, assigns(:content).version
    assert_equal 'text/html', @response.content_type
    assert_equal 'attachment; filename="CookBook_documentation.html"',
                  @response.headers['Content-Disposition']
    assert_tag 'h1', :content => 'CookBook documentation'
  end

  def test_show_txt
    @request.session[:user_id] = 2
    get :show, :project_id => 1, :format => 'txt'
    assert_response :success
    assert_not_nil assigns(:page)
    assert_equal 'text/plain', @response.content_type
    assert_equal 'attachment; filename="CookBook_documentation.txt"',
                  @response.headers['Content-Disposition']
    assert_include 'h1. CookBook documentation', @response.body
  end

  def test_show_versioned_txt
    @request.session[:user_id] = 2
    get :show, :project_id => 1, :format => 'txt', :version => 2
    assert_response :success
    assert_not_nil assigns(:content)
    assert_equal 2, assigns(:content).version
    assert_equal 'text/plain', @response.content_type
    assert_equal 'attachment; filename="CookBook_documentation.txt"',
                  @response.headers['Content-Disposition']
    assert_include 'h1. CookBook documentation', @response.body
  end

  def test_edit_unprotected_page
    # Non members can edit unprotected wiki pages
    @request.session[:user_id] = 4
    get :edit, :project_id => 1, :id => 'Another_page'
    assert_response :success
    assert_template 'edit'
  end

  def test_edit_protected_page_by_nonmember
    # Non members can't edit protected wiki pages
    @request.session[:user_id] = 4
    get :edit, :project_id => 1, :id => 'CookBook_documentation'
    assert_response 403
  end

  def test_edit_protected_page_by_member
    @request.session[:user_id] = 2
    get :edit, :project_id => 1, :id => 'CookBook_documentation'
    assert_response :success
    assert_template 'edit'
  end

  def test_history_of_non_existing_page_should_return_404
    get :history, :project_id => 1, :id => 'Unknown_page'
    assert_response 404
  end

  def test_add_attachment
    @request.session[:user_id] = 2
    assert_difference 'Attachment.count' do
      post :add_attachment, :project_id => 1, :id => 'CookBook_documentation',
        :attachments => {'1' => {'file' => uploaded_test_file('testfile.txt', 'text/plain'), 'description' => 'test file'}}
    end
    attachment = Attachment.first(:order => 'id DESC')
    assert_equal Wiki.find(1).find_page('CookBook_documentation'), attachment.container
  end
end
