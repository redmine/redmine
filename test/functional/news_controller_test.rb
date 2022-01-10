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

class NewsControllerTest < Redmine::ControllerTest
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :enabled_modules, :news, :comments,
           :attachments, :user_preferences

  def setup
    User.current = nil
  end

  def test_index
    get :index
    assert_response :success
    assert_select 'h3 a', :text => 'eCookbook first release !'
  end

  def test_index_with_project
    get(:index, :params => {:project_id => 1})
    assert_response :success
    assert_select 'h3 a', :text => 'eCookbook first release !'
  end

  def test_index_with_invalid_project_should_respond_with_404
    get(:index, :params => {:project_id => 999})
    assert_response 404
  end

  def test_index_without_permission_should_fail
    Role.all.each {|r| r.remove_permission! :view_news}
    @request.session[:user_id] = 2

    get :index
    assert_response 403
  end

  def test_index_without_manage_news_permission_should_not_display_add_news_link
    user = User.find(2)
    @request.session[:user_id] = user.id
    Role.all.each {|r| r.remove_permission! :manage_news}
    get :index
    assert_select '.add-news-link', count: 0

    user.members.first.roles.first.add_permission! :manage_news
    get :index
    assert_select '.add-news-link', count: 1
  end

  def test_show
    get(:show, :params => {:id => 1})
    assert_response :success
    assert_select 'h2', :text => 'eCookbook first release !'
  end

  def test_show_should_show_attachments
    attachment = Attachment.first
    attachment.container = News.find(1)
    attachment.save!

    get(:show, :params => {:id => 1})
    assert_response :success
    assert_select 'a', :text => attachment.filename
  end

  def test_show_with_comments_in_reverse_order
    user = User.find(1)
    user.pref[:comments_sorting] = 'desc'
    user.pref.save!

    @request.session[:user_id] = 1
    get(:show, :params => {:id => 1})
    assert_response :success

    comments = css_select('#comments .wiki').map(&:text).map(&:strip)
    assert_equal ["This is an other comment", "my first comment"], comments
  end

  def test_show_not_found
    get(:show, :params => {:id => 999})
    assert_response 404
  end

  def test_get_new_with_project_id
    @request.session[:user_id] = 2
    get(:new, :params => {:project_id => 1})
    assert_response :success
    assert_select 'select[name=project_id]', false
    assert_select 'input[name=?]', 'news[title]'
  end

  def test_get_new_without_project_id
    @request.session[:user_id] = 2
    get(:new)
    assert_response :success
    assert_select 'select[name=project_id]'
    assert_select 'input[name=?]', 'news[title]'
  end

  def test_get_new_if_user_does_not_have_permission
    @request.session[:user_id] = 2
    User.find(2).roles.each{|u| u.remove_permission! :manage_news }

    get(:new)
    assert_response :forbidden
    assert_select 'select[name=project_id]', false
    assert_select 'input[name=?]', 'news[title]', count: 0
  end

  def test_post_create
    ActionMailer::Base.deliveries.clear
    @request.session[:user_id] = 2

    with_settings :notified_events => %w(news_added) do
      post(
        :create,
        :params => {
          :project_id => 1,
          :news => {
            :title => 'NewsControllerTest',
            :description => 'This is the description',
            :summary => ''
          }
        }
      )
    end
    assert_redirected_to '/projects/ecookbook/news'

    news = News.find_by_title('NewsControllerTest')
    assert_not_nil news
    assert_equal 'This is the description', news.description
    assert_equal User.find(2), news.author
    assert_equal Project.find(1), news.project
    assert_equal 2, ActionMailer::Base.deliveries.size
  end

  def test_post_create_with_cross_project_param
    ActionMailer::Base.deliveries.clear
    @request.session[:user_id] = 2

    with_settings :notified_events => %w(news_added) do
      post(
        :create,
        :params => {
          :project_id => 1,
          :cross_project => '1',
          :news => {
            :title => 'NewsControllerTest',
            :description => 'This is the description',
            :summary => ''
          }
        }
      )
    end
    assert_redirected_to '/news'

    news = News.find_by(title: 'NewsControllerTest')
    assert_not_nil news
    assert_equal 'This is the description', news.description
    assert_equal User.find(2), news.author
    assert_equal Project.find(1), news.project
    assert_equal 2, ActionMailer::Base.deliveries.size
  end

  def test_post_create_with_attachment
    set_tmp_attachments_directory
    ActionMailer::Base.deliveries.clear
    @request.session[:user_id] = 2
    assert_difference 'News.count' do
      assert_difference 'Attachment.count' do
        with_settings :notified_events => %w(news_added) do
          post(
            :create,
            :params => {
              :project_id => 1,
              :news => {
                :title => 'Test',
                :description => 'This is the description'
              },
              :attachments => {
                '1' => {
                  'file' => uploaded_test_file('testfile.txt', 'text/plain')
                }
              }
            }
          )
        end
      end
    end
    attachment = Attachment.order('id DESC').first
    news = News.order('id DESC').first
    assert_equal news, attachment.container
    assert_select_email do
      # link to the attachments download
      assert_select 'fieldset.attachments' do
        assert_select 'a[href=?]',
                      "http://localhost:3000/attachments/download/#{attachment.id}/testfile.txt",
                      :text => 'testfile.txt'
      end
    end
  end

  def test_post_create_with_validation_failure
    @request.session[:user_id] = 2
    post(
      :create,
      :params => {
        :project_id => 1,
        :news => {
          :title => '',
          :description => 'This is the description',
          :summary => ''
        }
      }
    )
    assert_response :success
    assert_select_error /title cannot be blank/i
  end

  def test_get_edit
    @request.session[:user_id] = 2
    get(:edit, :params => {:id => 1})
    assert_response :success
    assert_select 'input[name=?][value=?]', 'news[title]', 'eCookbook first release !'
  end

  def test_put_update
    @request.session[:user_id] = 2
    put(
      :update,
      :params => {
        :id => 1,
        :news => {
          :description => 'Description changed by test_post_edit'
        }
      }
    )
    assert_redirected_to '/news/1'
    news = News.find(1)
    assert_equal 'Description changed by test_post_edit', news.description
  end

  def test_put_update_with_attachment
    set_tmp_attachments_directory
    @request.session[:user_id] = 2
    assert_no_difference 'News.count' do
      assert_difference 'Attachment.count' do
        put(
          :update,
          :params => {
            :id => 1,
            :news => {
              :description => 'This is the description'
            },
            :attachments => {
              '1' => {
                'file' => uploaded_test_file('testfile.txt', 'text/plain')
              }
            }
          }
        )
      end
    end
    attachment = Attachment.order('id DESC').first
    assert_equal News.find(1), attachment.container
  end

  def test_update_with_failure
    @request.session[:user_id] = 2
    put(
      :update,
      :params => {
        :id => 1,
        :news => {
          :description => ''
        }
      }
    )
    assert_response :success
    assert_select_error /description cannot be blank/i
  end

  def test_destroy
    @request.session[:user_id] = 2
    delete(:destroy, :params => {:id => 1})
    assert_redirected_to '/projects/ecookbook/news'
    assert_equal 'Successful deletion.', flash[:notice]
    assert_nil News.find_by_id(1)
  end
end
