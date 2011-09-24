# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
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

require File.expand_path('../../../test_helper', __FILE__)

class ApiTest::IssueRelationsTest < ActionController::IntegrationTest
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :workflows,
           :issue_relations

  def setup
    Setting.rest_api_enabled = '1'
  end

  context "/issues/:issue_id/relations" do
    context "GET" do
      should "return issue relations" do
        get '/issues/9/relations.xml', {}, :authorization => credentials('jsmith')

        assert_response :success
        assert_equal 'application/xml', @response.content_type

        assert_tag :tag => 'relations',
          :attributes => { :type => 'array' },
          :child => {
            :tag => 'relation',
            :child => {
              :tag => 'id',
              :content => '1'
            }
          }
      end
    end

    context "POST" do
      should "create a relation" do
        assert_difference('IssueRelation.count') do
          post '/issues/2/relations.xml', {:relation => {:issue_to_id => 7, :relation_type => 'relates'}}, :authorization => credentials('jsmith')
        end

        relation = IssueRelation.first(:order => 'id DESC')
        assert_equal 2, relation.issue_from_id
        assert_equal 7, relation.issue_to_id
        assert_equal 'relates', relation.relation_type

        assert_response :created
        assert_equal 'application/xml', @response.content_type
        assert_tag 'relation', :child => {:tag => 'id', :content => relation.id.to_s}
      end

      context "with failure" do
        should "return the errors" do
          assert_no_difference('IssueRelation.count') do
            post '/issues/2/relations.xml', {:relation => {:issue_to_id => 7, :relation_type => 'foo'}}, :authorization => credentials('jsmith')
          end

          assert_response :unprocessable_entity
          assert_tag :errors, :child => {:tag => 'error', :content => 'relation_type is not included in the list'}
        end
      end
    end
  end

  context "/relations/:id" do
    context "GET" do
      should "return the relation" do
        get '/relations/2.xml', {}, :authorization => credentials('jsmith')

        assert_response :success
        assert_equal 'application/xml', @response.content_type
        assert_tag 'relation', :child => {:tag => 'id', :content => '2'}
      end
    end

    context "DELETE" do
      should "delete the relation" do
        assert_difference('IssueRelation.count', -1) do
          delete '/relations/2.xml', {}, :authorization => credentials('jsmith')
        end

        assert_response :ok
        assert_nil IssueRelation.find_by_id(2)
      end
    end
  end

  def credentials(user, password=nil)
    ActionController::HttpAuthentication::Basic.encode_credentials(user, password || user)
  end
end
