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

class IssueRelationsControllerTest < Redmine::ControllerTest
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
      post(
        :create,
        :params => {
          :issue_id => 1,
          :relation => {
            :issue_to_id => '2',
            :relation_type => 'relates',
            :delay => ''
          }
        }
      )
    end
    relation = IssueRelation.order('id DESC').first
    assert_equal 1, relation.issue_from_id
    assert_equal 2, relation.issue_to_id
    assert_equal 'relates', relation.relation_type
  end

  def test_create_on_invalid_issue
    assert_no_difference 'IssueRelation.count' do
      post(
        :create,
        :params => {
          :issue_id => 999,
          :relation => {
            :issue_to_id => '2',
            :relation_type => 'relates',
            :delay => ''
          }
        }
      )
      assert_response 404
    end
  end

  def test_create_xhr
    assert_difference 'IssueRelation.count' do
      post(
        :create,
        :params => {
          :issue_id => 3,
          :relation => {
            :issue_to_id => '1',
            :relation_type => 'relates',
            :delay => ''
          }
        },
        :xhr => true
      )
      assert_response :success
      assert_equal 'text/javascript', response.media_type
    end
    relation = IssueRelation.order('id DESC').first
    assert_equal 1, relation.issue_from_id
    assert_equal 3, relation.issue_to_id

    assert_include 'Bug #1', response.body
  end

  def test_create_should_accept_id_with_hash
    assert_difference 'IssueRelation.count' do
      post(
        :create,
        :params => {
          :issue_id => 1,
          :relation => {
            :issue_to_id => '#2',
            :relation_type => 'relates',
            :delay => ''
          }
        }
      )
    end
    relation = IssueRelation.order('id DESC').first
    assert_equal 2, relation.issue_to_id
  end

  def test_create_should_strip_id
    assert_difference 'IssueRelation.count' do
      post(
        :create,
        :params => {
          :issue_id => 1,
          :relation => {
            :issue_to_id => ' 2  ',
            :relation_type => 'relates',
            :delay => ''
          }
        }
      )
    end
    relation = IssueRelation.order('id DESC').first
    assert_equal 2, relation.issue_to_id
  end

  def test_create_should_not_break_with_non_numerical_id
    assert_no_difference 'IssueRelation.count' do
      assert_nothing_raised do
        post(
          :create,
          :params => {
            :issue_id => 1,
            :relation => {
              :issue_to_id => 'foo',
              :relation_type => 'relates',
              :delay => ''
            }
          }
        )
      end
    end
  end

  def test_create_follows_relation_should_update_relations_list
    issue1 = Issue.generate!(:subject => 'Followed issue',
                             :start_date => Date.yesterday,
                             :due_date => Date.today)
    issue2 = Issue.generate!

    assert_difference 'IssueRelation.count' do
      post(
        :create,
        :params => {
          :issue_id => issue2.id,
          :relation => {
            :issue_to_id => issue1.id,
            :relation_type => 'follows',
            :delay => ''
          }
        },
        :xhr => true
      )
    end
    assert_include 'Followed issue', response.body
  end

  def test_should_create_relations_with_visible_issues_only
    with_settings :cross_project_issue_relations => '1' do
      assert_nil Issue.visible(User.find(3)).find_by_id(4)

      assert_no_difference 'IssueRelation.count' do
        post(
          :create,
          :params => {
            :issue_id => 1,
            :relation => {
              :issue_to_id => '4',
              :relation_type => 'relates',
              :delay => ''
            }
          }
        )
      end
    end
  end

  def test_create_xhr_with_failure
    assert_no_difference 'IssueRelation.count' do
      post(
        :create,
        :params => {
          :issue_id => 3,
          :relation => {
            :issue_to_id => '999',
            :relation_type => 'relates',
            :delay => ''
          }
        },
        :xhr => true
      )
      assert_response :success
      assert_equal 'text/javascript', response.media_type
    end
    assert_include 'Related issue cannot be blank', response.body
  end

  def test_create_duplicated_follows_relations_should_not_raise_exception
    IssueRelation.create(
      :issue_from => Issue.find(1), :issue_to => Issue.find(2),
      :relation_type => IssueRelation::TYPE_PRECEDES
    )

    assert_no_difference 'IssueRelation.count' do
      post(
        :create,
        :params => {
          :issue_id => 2,
          :relation => {
            :issue_to_id => 1,
            :relation_type => 'follows',
            :delay => ''
          }
        },
        :xhr => true
      )
    end

    assert_response :success
    assert_include 'has already been taken', response.body
  end

  def test_bulk_create_with_multiple_issue_to_id_issues
    assert_difference 'IssueRelation.count', +3 do
      post :create, :params => {
        :issue_id => 1,
        :relation => {
          # js autocomplete adds a comma at the end
          # issue to id should accept both id and hash with id
          :issue_to_id => '2,3,#7, ',
          :relation_type => 'relates',
          :delay => ''
        }
      },
      :xhr => true
    end

    assert_response :success
    relations = IssueRelation.where(:issue_from_id => 1, :issue_to_id => [2, 3, 7])
    assert_equal 3, relations.count
    # all relations types should be 'relates'
    relations.map {|r| assert_equal 'relates', r.relation_type}

    # no error messages should be returned in the response
    assert_not_include 'id=\"errorExplanation\"', response.body
  end

  def test_bulk_create_should_show_errors
    with_settings :cross_project_issue_relations => '0' do
      assert_difference 'IssueRelation.count', +3 do
        post :create, :params => {
          :issue_id => 1,
          :relation => {
            :issue_to_id => '1,2,3,4,5,7',
            :relation_type => 'relates',
            :delay => ''
          }
        },
        :xhr => true
      end
    end

    assert_response :success
    assert_equal 'text/javascript', response.media_type
    # issue #1 is invalid
    assert_include 'Related issue is invalid: #1', response.body
    # issues #4 and #5 can't be related by default
    assert_include 'Related issue cannot be blank', response.body
    assert_include 'Related issue doesn&#39;t belong to the same project', response.body
  end

  def test_destroy
    assert_difference 'IssueRelation.count', -1 do
      delete(:destroy, :params => {:id => '2'})
    end
  end

  def test_destroy_invalid_relation
    assert_no_difference 'IssueRelation.count' do
      delete(:destroy, :params => {:id => '999'})
      assert_response 404
    end
  end

  def test_destroy_xhr
    IssueRelation.create!(:relation_type => IssueRelation::TYPE_RELATES) do |r|
      r.issue_from_id = 3
      r.issue_to_id = 1
    end

    assert_difference 'IssueRelation.count', -1 do
      delete(:destroy, :params => {:id => '2'}, :xhr => true)
      assert_response :success
      assert_equal 'text/javascript', response.media_type
      assert_include 'relation-2', response.body
    end
  end
end
