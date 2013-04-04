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

class BoardsControllerTest < ActionController::TestCase
  fixtures :projects, :users, :members, :member_roles, :roles, :boards, :messages, :enabled_modules

  def setup
    User.current = nil
  end

  def test_index
    get :index, :project_id => 1
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:boards)
    assert_not_nil assigns(:project)
  end

  def test_index_not_found
    get :index, :project_id => 97
    assert_response 404
  end

  def test_index_should_show_messages_if_only_one_board
    Project.find(1).boards.slice(1..-1).each(&:destroy)

    get :index, :project_id => 1
    assert_response :success
    assert_template 'show'
    assert_not_nil assigns(:topics)
  end

  def test_show
    get :show, :project_id => 1, :id => 1
    assert_response :success
    assert_template 'show'
    assert_not_nil assigns(:board)
    assert_not_nil assigns(:project)
    assert_not_nil assigns(:topics)
  end

  def test_show_should_display_sticky_messages_first
    Message.update_all(:sticky => 0)
    Message.update_all({:sticky => 1}, {:id => 1})

    get :show, :project_id => 1, :id => 1
    assert_response :success

    topics = assigns(:topics)
    assert_not_nil topics
    assert topics.size > 1, "topics size was #{topics.size}"
    assert topics.first.sticky?
    assert topics.first.updated_on < topics.second.updated_on
  end

  def test_show_should_display_message_with_last_reply_first
    Message.update_all(:sticky => 0)

    # Reply to an old topic
    old_topic = Message.where(:board_id => 1, :parent_id => nil).order('created_on ASC').first
    reply = Message.new(:board_id => 1, :subject => 'New reply', :content => 'New reply', :author_id => 2)
    old_topic.children << reply

    get :show, :project_id => 1, :id => 1
    assert_response :success
    topics = assigns(:topics)
    assert_not_nil topics
    assert_equal old_topic, topics.first
  end

  def test_show_with_permission_should_display_the_new_message_form
    @request.session[:user_id] = 2
    get :show, :project_id => 1, :id => 1
    assert_response :success
    assert_template 'show'

    assert_select 'form#message-form' do
      assert_select 'input[name=?]', 'message[subject]'
    end
  end

  def test_show_atom
    get :show, :project_id => 1, :id => 1, :format => 'atom'
    assert_response :success
    assert_template 'common/feed'
    assert_not_nil assigns(:board)
    assert_not_nil assigns(:project)
    assert_not_nil assigns(:messages)
  end

  def test_show_not_found
    get :index, :project_id => 1, :id => 97
    assert_response 404
  end

  def test_new
    @request.session[:user_id] = 2
    get :new, :project_id => 1
    assert_response :success
    assert_template 'new'

    assert_select 'select[name=?]', 'board[parent_id]' do
      assert_select 'option', (Project.find(1).boards.size + 1)
      assert_select 'option[value=]', :text => ''
      assert_select 'option[value=1]', :text => 'Help'
    end
  end

  def test_new_without_project_boards
    Project.find(1).boards.delete_all
    @request.session[:user_id] = 2

    get :new, :project_id => 1
    assert_response :success
    assert_template 'new'

    assert_select 'select[name=?]', 'board[parent_id]', 0
  end

  def test_create
    @request.session[:user_id] = 2
    assert_difference 'Board.count' do
      post :create, :project_id => 1, :board => { :name => 'Testing', :description => 'Testing board creation'}
    end
    assert_redirected_to '/projects/ecookbook/settings/boards'
    board = Board.first(:order => 'id DESC')
    assert_equal 'Testing', board.name
    assert_equal 'Testing board creation', board.description
  end

  def test_create_with_parent
    @request.session[:user_id] = 2
    assert_difference 'Board.count' do
      post :create, :project_id => 1, :board => { :name => 'Testing', :description => 'Testing', :parent_id => 2}
    end
    assert_redirected_to '/projects/ecookbook/settings/boards'
    board = Board.first(:order => 'id DESC')
    assert_equal Board.find(2), board.parent
  end

  def test_create_with_failure
    @request.session[:user_id] = 2
    assert_no_difference 'Board.count' do
      post :create, :project_id => 1, :board => { :name => '', :description => 'Testing board creation'}
    end
    assert_response :success
    assert_template 'new'
  end

  def test_edit
    @request.session[:user_id] = 2
    get :edit, :project_id => 1, :id => 2
    assert_response :success
    assert_template 'edit'
  end

  def test_edit_with_parent
    board = Board.generate!(:project_id => 1, :parent_id => 2)
    @request.session[:user_id] = 2
    get :edit, :project_id => 1, :id => board.id
    assert_response :success
    assert_template 'edit'

    assert_select 'select[name=?]', 'board[parent_id]' do
      assert_select 'option[value=2][selected=selected]'
    end
  end

  def test_update
    @request.session[:user_id] = 2
    assert_no_difference 'Board.count' do
      put :update, :project_id => 1, :id => 2, :board => { :name => 'Testing', :description => 'Testing board update'}
    end
    assert_redirected_to '/projects/ecookbook/settings/boards'
    assert_equal 'Testing', Board.find(2).name
  end

  def test_update_position
    @request.session[:user_id] = 2
    put :update, :project_id => 1, :id => 2, :board => { :move_to => 'highest'}
    assert_redirected_to '/projects/ecookbook/settings/boards'
    board = Board.find(2)
    assert_equal 1, board.position
  end

  def test_update_with_failure
    @request.session[:user_id] = 2
    put :update, :project_id => 1, :id => 2, :board => { :name => '', :description => 'Testing board update'}
    assert_response :success
    assert_template 'edit'
  end

  def test_destroy
    @request.session[:user_id] = 2
    assert_difference 'Board.count', -1 do
      delete :destroy, :project_id => 1, :id => 2
    end
    assert_redirected_to '/projects/ecookbook/settings/boards'
    assert_nil Board.find_by_id(2)
  end
end
