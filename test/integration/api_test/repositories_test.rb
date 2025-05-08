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

class Redmine::ApiTest::RepositoriesTest < Redmine::ApiTest::Base
  test 'POST /projects/:id/repository/:repository_id/revisions/:rev/issues.xml should add related issue' do
    changeset = Changeset.find(103)
    assert_equal [], changeset.issue_ids
    assert_difference 'Changeset.find(103).issues.size' do
      post '/projects/1/repository/10/revisions/4/issues.xml', :headers => credentials('jsmith'), :params => {:issue_id => '2'}
    end
    assert_response :no_content
    assert_equal [2], changeset.reload.issue_ids
  end

  test 'POST /projects/:id/repository/:repository_id/revisions/:rev/issues.json should add related issue' do
    changeset = Changeset.find(103)
    assert_equal [], changeset.issue_ids
    assert_difference 'Changeset.find(103).issues.size' do
      post '/projects/1/repository/10/revisions/4/issues.json', :headers => credentials('jsmith'), :params => {:issue_id => '2'}
    end
    assert_response :no_content
    assert_equal [2], changeset.reload.issue_ids
  end

  test 'POST /projects/:id/repository/:repository_id/revisions/:rev/issues.xml should accept issue_id with sharp' do
    changeset = Changeset.find(103)
    assert_equal [], changeset.issue_ids
    assert_difference 'Changeset.find(103).issues.size' do
      post '/projects/1/repository/10/revisions/4/issues.xml', :headers => credentials('jsmith'), :params => {:issue_id => '#2'}
    end
    assert_response :no_content
    assert_equal [2], changeset.reload.issue_ids
  end

  test 'POST /projects/:id/repository/:repository_id/revisions/:rev/issues.json should accept issue_id with sharp' do
    changeset = Changeset.find(103)
    assert_equal [], changeset.issue_ids
    assert_difference 'Changeset.find(103).issues.size' do
      post '/projects/1/repository/10/revisions/4/issues.json', :headers => credentials('jsmith'), :params => {:issue_id => '#2'}
    end
    assert_response :no_content
    assert_equal [2], changeset.reload.issue_ids
  end

  test 'POST /projects/:id/repository/:repository_id/revisions/:rev/issues.xml with invalid issue_id' do
    assert_no_difference 'Changeset.find(103).issues.size' do
      post '/projects/1/repository/10/revisions/4/issues.xml', :headers => credentials('jsmith'), :params => {:issue_id => '9999'}
    end
    assert_response :unprocessable_content
    assert_select 'errors error', :text => 'Issue is invalid'
  end

  test 'POST /projects/:id/repository/:repository_id/revisions/:rev/issues.json with invalid issue_id' do
    assert_no_difference 'Changeset.find(103).issues.size' do
      post '/projects/1/repository/10/revisions/4/issues.json', :headers => credentials('jsmith'), :params => {:issue_id => '9999'}
    end
    assert_response :unprocessable_content
    json = ActiveSupport::JSON.decode(response.body)
    assert json['errors'].include?('Issue is invalid')
  end

  test 'DELETE /projects/:id/repository/:repository_id/revisions/:rev/issues/:issue_id.xml should remove related issue' do
    changeset = Changeset.find(103)
    changeset.issues << Issue.find(1)
    changeset.issues << Issue.find(2)
    assert_difference 'Changeset.find(103).issues.size', -1 do
      delete '/projects/1/repository/10/revisions/4/issues/2.xml', :headers => credentials('jsmith')
    end
    assert_response :no_content
    assert_equal [1], changeset.reload.issue_ids
  end

  test 'DELETE /projects/:id/repository/:repository_id/revisions/:rev/issues/:issue_id.json should remove related issue' do
    changeset = Changeset.find(103)
    changeset.issues << Issue.find(1)
    changeset.issues << Issue.find(2)
    assert_difference 'Changeset.find(103).issues.size', -1 do
      delete '/projects/1/repository/10/revisions/4/issues/2.json', :headers => credentials('jsmith')
    end
    assert_response :no_content
    assert_equal [1], changeset.reload.issue_ids
  end
end
