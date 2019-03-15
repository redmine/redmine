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

require File.expand_path('../../../test_helper', __FILE__)

class Redmine::ApiTest::SearchTest < Redmine::ApiTest::Base
  fixtures :projects, :projects_trackers,
           :enabled_modules, :roles, :users, :members, :member_roles,
           :issues, :trackers, :issue_statuses, :enumerations,
           :workflows,
           :custom_fields, :custom_values,
           :custom_fields_projects, :custom_fields_trackers,
           :repositories, :changesets

  test "GET /search.xml should return xml content" do
    get '/search.xml'

    assert_response :success
    assert_equal 'application/xml', @response.content_type
  end

  test "GET /search.json should return json content" do
    get '/search.json'

    assert_response :success
    assert_equal 'application/json', @response.content_type

    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json
    assert_kind_of Array, json['results']
  end

  test "GET /search.xml without query strings should return empty results" do
    get '/search.xml', :params => {:q => '', :all_words => ''}

    assert_response :success
    assert_select 'result', 0
  end

  test "GET /search.xml with query strings should return results" do
    issue = Issue.generate!(:subject => 'searchapi')

    get '/search.xml', :params => {:q => 'searchapi', :all_words => ''}

    assert_response :success

    assert_select 'results[type=array]' do
      assert_select 'result', 1

      assert_select 'result' do
        assert_select 'id',          :text => issue.id.to_s
        assert_select 'title',       :text => "Bug ##{issue.id} (New): searchapi"
        assert_select 'type',        :text => 'issue'
        assert_select 'url',         :text => "http://www.example.com/issues/#{issue.id}"
        assert_select 'description', :text => ''
        assert_select 'datetime'
      end
    end
  end

  test "GET /search.xml should paginate" do
    issue = (0..10).map {Issue.generate! :subject => 'search_with_limited_results'}.reverse.map(&:id)

    get '/search.json', :params => {:q => 'search_with_limited_results', :limit => 4}
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal 11, json['total_count']
    assert_equal 0, json['offset']
    assert_equal 4, json['limit']
    assert_equal issue[0..3], json['results'].map {|r| r['id']}

    get '/search.json', :params => {:q => 'search_with_limited_results', :offset => 8, :limit => 4}
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal 11, json['total_count']
    assert_equal 8, json['offset']
    assert_equal 4, json['limit']
    assert_equal issue[8..10], json['results'].map {|r| r['id']}
  end
 
  test "GET /search.xml should not quick jump to the issue with given id" do
    get '/search.xml', :params => {:q => '3'}
    assert_response :success
  end
end
