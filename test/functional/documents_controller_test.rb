# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

class DocumentsControllerTest < ActionController::TestCase
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :enabled_modules, :documents, :enumerations,
           :groups_users, :attachments

  def setup
    User.current = nil
  end

  def test_index
    # Sets a default category
    e = Enumeration.find_by_name('Technical documentation')
    e.update_attributes(:is_default => true)

    get :index, :project_id => 'ecookbook'
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:grouped)

    # Default category selected in the new document form
    assert_select 'select[name=?]', 'document[category_id]' do
      assert_select 'option[selected=selected]', :text => 'Technical documentation'

      assert ! DocumentCategory.find(16).active?
      assert_select 'option[value="16"]', 0
    end
  end

  def test_index_grouped_by_date
    get :index, :project_id => 'ecookbook', :sort_by => 'date'
    assert_response :success
    assert_select 'h3', :text => '2007-02-12'
  end

  def test_index_grouped_by_title
    get :index, :project_id => 'ecookbook', :sort_by => 'title'
    assert_response :success
    assert_select 'h3', :text => 'T'
  end

  def test_index_grouped_by_author
    get :index, :project_id => 'ecookbook', :sort_by => 'author'
    assert_response :success
    assert_select 'h3', :text => 'John Smith'
  end

  def test_index_with_long_description
    # adds a long description to the first document
    doc = documents(:documents_001)
    doc.update_attributes(:description => <<LOREM)
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut egestas, mi vehicula varius varius, ipsum massa fermentum orci, eget tristique ante sem vel mi. Nulla facilisi. Donec enim libero, luctus ac sagittis sit amet, vehicula sagittis magna. Duis ultrices molestie ante, eget scelerisque sem iaculis vitae. Etiam fermentum mauris vitae metus pharetra condimentum fermentum est pretium. Proin sollicitudin elementum quam quis pharetra.  Aenean facilisis nunc quis elit volutpat mollis. Aenean eleifend varius euismod. Ut dolor est, congue eget dapibus eget, elementum eu odio. Integer et lectus neque, nec scelerisque nisi. EndOfLineHere

Vestibulum non velit mi. Aliquam scelerisque libero ut nulla fringilla a sollicitudin magna rhoncus.  Praesent a nunc lorem, ac porttitor eros. Sed ac diam nec neque interdum adipiscing quis quis justo. Donec arcu nunc, fringilla eu dictum at, venenatis ac sem. Vestibulum quis elit urna, ac mattis sapien. Lorem ipsum dolor sit amet, consectetur adipiscing elit.
LOREM

    get :index, :project_id => 'ecookbook'
    assert_response :success
    assert_template 'index'

    # should only truncate on new lines to avoid breaking wiki formatting
    assert_select '.wiki p', :text => (doc.description.split("\n").first + '...')
    assert_select '.wiki p', :text => Regexp.new(Regexp.escape("EndOfLineHere..."))
  end

  def test_show
    get :show, :id => 1
    assert_response :success
    assert_template 'show'
  end

  def test_new
    @request.session[:user_id] = 2
    get :new, :project_id => 1
    assert_response :success
    assert_template 'new'
  end

  def test_create_with_one_attachment
    ActionMailer::Base.deliveries.clear
    @request.session[:user_id] = 2
    set_tmp_attachments_directory

    with_settings :notified_events => %w(document_added) do
      post :create, :project_id => 'ecookbook',
               :document => { :title => 'DocumentsControllerTest#test_post_new',
                              :description => 'This is a new document',
                              :category_id => 2},
               :attachments => {'1' => {'file' => uploaded_test_file('testfile.txt', 'text/plain')}}
    end
    assert_redirected_to '/projects/ecookbook/documents'

    document = Document.find_by_title('DocumentsControllerTest#test_post_new')
    assert_not_nil document
    assert_equal Enumeration.find(2), document.category
    assert_equal 1, document.attachments.size
    assert_equal 'testfile.txt', document.attachments.first.filename
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  def test_create_with_failure
    @request.session[:user_id] = 2
    assert_no_difference 'Document.count' do
      post :create, :project_id => 'ecookbook', :document => { :title => ''}
    end
    assert_response :success
    assert_template 'new'
  end

  def test_create_non_default_category
    @request.session[:user_id] = 2
    category2 = Enumeration.find_by_name('User documentation')
    category2.update_attributes(:is_default => true)
    category1 = Enumeration.find_by_name('Uncategorized')
    post :create,
         :project_id => 'ecookbook',
         :document => { :title => 'no default',
                        :description => 'This is a new document',
                        :category_id => category1.id }
    assert_redirected_to '/projects/ecookbook/documents'
    doc = Document.find_by_title('no default')
    assert_not_nil doc
    assert_equal category1.id, doc.category_id
    assert_equal category1, doc.category
  end

  def test_edit
    @request.session[:user_id] = 2
    get :edit, :id => 1
    assert_response :success
    assert_template 'edit'
  end

  def test_update
    @request.session[:user_id] = 2
    put :update, :id => 1, :document => {:title => 'test_update'}
    assert_redirected_to '/documents/1'
    document = Document.find(1)
    assert_equal 'test_update', document.title
  end

  def test_update_with_failure
    @request.session[:user_id] = 2
    put :update, :id => 1, :document => {:title => ''}
    assert_response :success
    assert_template 'edit'
  end

  def test_destroy
    @request.session[:user_id] = 2
    assert_difference 'Document.count', -1 do
      delete :destroy, :id => 1
    end
    assert_redirected_to '/projects/ecookbook/documents'
    assert_nil Document.find_by_id(1)
  end

  def test_add_attachment
    @request.session[:user_id] = 2
    assert_difference 'Attachment.count' do
      post :add_attachment, :id => 1,
        :attachments => {'1' => {'file' => uploaded_test_file('testfile.txt', 'text/plain')}}
    end
    attachment = Attachment.order('id DESC').first
    assert_equal Document.find(1), attachment.container
  end
end
