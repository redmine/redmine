# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
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

require_relative '../../test_helper'

class Redmine::ApiTest::IssueRelationsTest < Redmine::ApiTest::Base
  test "GET /issues/:issue_id/relations.xml should return issue relations" do
    get '/issues/9/relations.xml', :headers => credentials('jsmith')

    assert_response :success
    assert_equal 'application/xml', @response.media_type

    assert_select 'relations[type=array] relation id', :text => '1'
  end

  test "POST /issues/:issue_id/relations.xml should create the relation" do
    assert_difference('IssueRelation.count') do
      post(
        '/issues/2/relations.xml',
        :params => {:relation => {:issue_to_id => "7", :relation_type => 'relates'}},
        :headers => credentials('jsmith')
      )
    end

    relation = IssueRelation.order('id DESC').first
    assert_equal 2, relation.issue_from_id
    assert_equal 7, relation.issue_to_id
    assert_equal 'relates', relation.relation_type

    assert_response :created
    assert_equal 'application/xml', @response.media_type
    assert_select 'relation id', :text => relation.id.to_s
  end

  test "POST /issues/:issue_id/relations.json with numeric issue to id should create the relation" do
    assert_difference('IssueRelation.count') do
      post(
        '/issues/2/relations.json',
        :params => {:relation => {:issue_to_id => 7, :relation_type => 'relates'}},
        :headers => credentials('jsmith'),
        :as => :json
      )
    end

    relation = IssueRelation.order('id DESC').first
    assert_equal 2, relation.issue_from_id
    assert_equal 7, relation.issue_to_id
    assert_equal 'relates', relation.relation_type

    assert_response :created
    assert_equal 'application/json', @response.media_type
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal relation.id, json['relation']['id']
  end

  test "POST /issues/:issue_id/relations.xml with failure should return errors" do
    assert_no_difference('IssueRelation.count') do
      post(
        '/issues/2/relations.xml',
        :params => {:relation => {:issue_to_id => 7, :relation_type => 'foo'}},
        :headers => credentials('jsmith')
      )
    end

    assert_response :unprocessable_content
    assert_select 'errors error', :text => /Relation type is not included in the list/
  end

  test "GET /relations/:id.xml should return the relation" do
    get '/relations/2.xml', :headers => credentials('jsmith')

    assert_response :success
    assert_equal 'application/xml', @response.media_type
    assert_select 'relation id', :text => '2'
  end

  test "DELETE /relations/:id.xml should delete the relation" do
    assert_difference('IssueRelation.count', -1) do
      delete '/relations/2.xml', :headers => credentials('jsmith')
    end

    assert_response :no_content
    assert_equal '', @response.body
    assert_nil IssueRelation.find_by_id(2)
  end
end
