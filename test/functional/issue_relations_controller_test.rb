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

class IssueRelationsControllerTest < ActionController::TestCase
  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :issues,
           :issue_statuses,
           :issue_relations,
           :enabled_modules,
           :enumerations,
           :trackers,
           :projects_trackers

  def setup
    User.current = nil
    @request.session[:user_id] = 3
  end

  def test_create
    assert_difference 'IssueRelation.count' do
      post :create, :issue_id => 1,
                 :relation => {:issue_to_id => '2', :relation_type => 'relates', :delay => ''}
    end
    relation = IssueRelation.first(:order => 'id DESC')
    assert_equal 1, relation.issue_from_id
    assert_equal 2, relation.issue_to_id
    assert_equal 'relates', relation.relation_type
  end

  def test_create_xhr
    assert_difference 'IssueRelation.count' do
      xhr :post, :create, :issue_id => 3, :relation => {:issue_to_id => '1', :relation_type => 'relates', :delay => ''}
      assert_response :success
      assert_template 'create'
      assert_equal 'text/javascript', response.content_type
    end
    relation = IssueRelation.first(:order => 'id DESC')
    assert_equal 3, relation.issue_from_id
    assert_equal 1, relation.issue_to_id

    assert_match /Bug #1/, response.body
  end

  def test_create_should_accept_id_with_hash
    assert_difference 'IssueRelation.count' do
      post :create, :issue_id => 1,
                 :relation => {:issue_to_id => '#2', :relation_type => 'relates', :delay => ''}
    end
    relation = IssueRelation.first(:order => 'id DESC')
    assert_equal 2, relation.issue_to_id
  end

  def test_create_should_strip_id
    assert_difference 'IssueRelation.count' do
      post :create, :issue_id => 1,
                 :relation => {:issue_to_id => ' 2  ', :relation_type => 'relates', :delay => ''}
    end
    relation = IssueRelation.first(:order => 'id DESC')
    assert_equal 2, relation.issue_to_id
  end

  def test_create_should_not_break_with_non_numerical_id
    assert_no_difference 'IssueRelation.count' do
      assert_nothing_raised do
        post :create, :issue_id => 1,
                   :relation => {:issue_to_id => 'foo', :relation_type => 'relates', :delay => ''}
      end
    end
  end

  def test_create_follows_relation_should_update_relations_list
    issue1 = Issue.generate!(:subject => 'Followed issue', :start_date => Date.yesterday, :due_date => Date.today)
    issue2 = Issue.generate!

    assert_difference 'IssueRelation.count' do
      xhr :post, :create, :issue_id => issue2.id,
                 :relation => {:issue_to_id => issue1.id, :relation_type => 'follows', :delay => ''}
    end
    assert_match /Followed issue/, response.body
  end

  def test_should_create_relations_with_visible_issues_only
    Setting.cross_project_issue_relations = '1'
    assert_nil Issue.visible(User.find(3)).find_by_id(4)

    assert_no_difference 'IssueRelation.count' do
      post :create, :issue_id => 1,
                 :relation => {:issue_to_id => '4', :relation_type => 'relates', :delay => ''}
    end
  end

  def test_create_xhr_with_failure
    assert_no_difference 'IssueRelation.count' do
      xhr :post, :create, :issue_id => 3, :relation => {:issue_to_id => '999', :relation_type => 'relates', :delay => ''}

      assert_response :success
      assert_template 'create'
      assert_equal 'text/javascript', response.content_type
    end

    assert_match /errorExplanation/, response.body
  end

  def test_destroy
    assert_difference 'IssueRelation.count', -1 do
      delete :destroy, :id => '2'
    end
  end

  def test_destroy_xhr
    IssueRelation.create!(:relation_type => IssueRelation::TYPE_RELATES) do |r|
      r.issue_from_id = 3
      r.issue_to_id = 1
    end

    assert_difference 'IssueRelation.count', -1 do
      xhr :delete, :destroy, :id => '2'

      assert_response :success
      assert_template 'destroy'
      assert_equal 'text/javascript', response.content_type
      assert_match /relation-2/, response.body
    end
  end
end
