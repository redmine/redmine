# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

class QueriesControllerTest < Redmine::ControllerTest
  fixtures :projects, :enabled_modules,
           :users, :email_addresses,
           :members, :member_roles, :roles,
           :trackers, :issue_statuses, :issue_categories, :enumerations, :versions,
           :issues, :custom_fields, :custom_values,
           :queries

  def setup
    User.current = nil
  end

  def test_index
    get :index
    # HTML response not implemented
    assert_response 406
  end

  def test_new_project_query
    @request.session[:user_id] = 2
    get :new, :params => {
        :project_id => 1
      }
    assert_response :success

    assert_select 'input[name=?][value="0"][checked=checked]', 'query[visibility]'
    assert_select 'input[name=query_is_for_all][type=checkbox]:not([checked]):not([disabled])'
    assert_select 'select[name=?]', 'c[]' do
      assert_select 'option[value=tracker]'
      assert_select 'option[value=subject]'
    end
  end

  def test_new_global_query
    @request.session[:user_id] = 2
    get :new
    assert_response :success

    assert_select 'input[name=?]', 'query[visibility]', 0
    assert_select 'input[name=query_is_for_all][type=checkbox][checked]:not([disabled])'
  end

  def test_new_on_invalid_project
    @request.session[:user_id] = 2
    get :new, :params => {
        :project_id => 'invalid'
      }
    assert_response 404
  end

  def test_new_should_not_render_show_inline_columns_option_for_query_without_available_inline_columns
    @request.session[:user_id] = 1
    get :new, :params => {
        :type => 'ProjectQuery'
      }

    assert_response :success
    assert_select 'p[class=?]', 'block_columns', 0
  end

  def test_new_should_not_render_show_totals_option_for_query_without_totable_columns
    @request.session[:user_id] = 1
    get :new, :params => {
        :type => 'ProjectQuery'
      }

    assert_response :success
    assert_select 'p[class=?]', 'totables_columns', 0
  end

  def test_new_time_entry_query
    @request.session[:user_id] = 2
    get :new, :params => {
        :project_id => 1,
        :type => 'TimeEntryQuery'
      }
    assert_response :success
    assert_select 'input[name=type][value=?]', 'TimeEntryQuery'
    assert_select 'p[class=?]', 'totable_columns', 1
    assert_select 'p[class=?]', 'block_columns', 0
  end

  def test_new_project_query_for_projects
    @request.session[:user_id] = 1
    get :new, :params => {
        :type => 'ProjectQuery'
      }
    assert_response :success
    assert_select 'input[name=type][value=?]', 'ProjectQuery'
  end

  def test_new_project_query_should_not_render_roles_visibility_options
    @request.session[:user_id] = 1
    get :new, :params => {
        :type => 'ProjectQuery'
      }

    assert_response :success
    assert_select 'input[id=?]', 'query_visibility_0', 1
    assert_select 'input[id=?]', 'query_visibility_2', 1
    assert_select 'input[id=?]', 'query_visibility_1', 0
  end

  def test_new_project_query_should_not_render_for_all_projects_option
    @request.session[:user_id] = 1
    get :new, :params => {
        :type => 'ProjectQuery'
      }

    assert_response :success
    assert_select 'input[name=?]', 'for_all_projects', 0
  end

  def test_new_time_entry_query_should_select_spent_time_from_main_menu
    @request.session[:user_id] = 2
    get :new, :params => {
        :project_id => 1,
        :type => 'TimeEntryQuery'
      }
    assert_response :success
    assert_select '#main-menu a.time-entries.selected'
  end

  def test_new_time_entry_query_with_issue_tracking_module_disabled_should_be_allowed
    Project.find(1).disable_module! :issue_tracking

    @request.session[:user_id] = 2
    get :new, :params => {
        :project_id => 1,
        :type => 'TimeEntryQuery'
      }
    assert_response :success
  end

  def test_create_project_public_query
    @request.session[:user_id] = 2
    post :create, :params => {
        :project_id => 'ecookbook',
        :default_columns => '1',
        :f => ["status_id", "assigned_to_id"],
        :op => {
          "assigned_to_id" => "=", "status_id" => "o"
        },
        :v => {
          "assigned_to_id" => ["1"], "status_id" => ["1"]
        },
        :query => {
          "name" => "test_new_project_public_query", "visibility" => "2"
        }
      }

    q = Query.find_by_name('test_new_project_public_query')
    assert_redirected_to :controller => 'issues', :action => 'index', :project_id => 'ecookbook', :query_id => q
    assert q.is_public?
    assert q.has_default_columns?
    assert q.valid?
  end

  def test_create_project_private_query
    @request.session[:user_id] = 3
    post :create, :params => {
        :project_id => 'ecookbook',
        :default_columns => '1',
        :fields => ["status_id", "assigned_to_id"],
        :operators => {
          "assigned_to_id" => "=", "status_id" => "o"
        },
        :values => {
          "assigned_to_id" => ["1"], "status_id" => ["1"]
        },
        :query => {
          "name" => "test_new_project_private_query", "visibility" => "0"
        }
      }

    q = Query.find_by_name('test_new_project_private_query')
    assert_redirected_to :controller => 'issues', :action => 'index', :project_id => 'ecookbook', :query_id => q
    assert !q.is_public?
    assert q.has_default_columns?
    assert q.valid?
  end

  def test_create_project_roles_query
    @request.session[:user_id] = 2
    post :create, :params => {
        :project_id => 'ecookbook',
        :default_columns => '1',
        :fields => ["status_id", "assigned_to_id"],
        :operators => {
          "assigned_to_id" => "=", "status_id" => "o"
        },
        :values => {
          "assigned_to_id" => ["1"], "status_id" => ["1"]
        },
        :query => {
          "name" => "test_create_project_roles_query", "visibility" => "1", "role_ids" => ["1", "2", ""]
        }
      }

    q = Query.find_by_name('test_create_project_roles_query')
    assert_redirected_to :controller => 'issues', :action => 'index', :project_id => 'ecookbook', :query_id => q
    assert_equal Query::VISIBILITY_ROLES, q.visibility
    assert_equal [1, 2], q.roles.ids.sort
  end

  def test_create_global_private_query_with_custom_columns
    @request.session[:user_id] = 3
    post :create, :params => {
        :fields => ["status_id", "assigned_to_id"],
        :operators => {
          "assigned_to_id" => "=", "status_id" => "o"
        },
        :values => {
          "assigned_to_id" => ["me"], "status_id" => ["1"]
        },
        :query => {
          "name" => "test_new_global_private_query", "visibility" => "0"
        },
        :c => ["", "tracker", "subject", "priority", "category"]
      }

    q = Query.find_by_name('test_new_global_private_query')
    assert_redirected_to :controller => 'issues', :action => 'index', :project_id => nil, :query_id => q
    assert !q.is_public?
    assert !q.has_default_columns?
    assert_equal [:id, :tracker, :subject, :priority, :category], q.columns.collect {|c| c.name}
    assert q.valid?
  end

  def test_create_global_query_with_custom_filters
    @request.session[:user_id] = 3
    post :create, :params => {
        :fields => ["assigned_to_id"],
        :operators => {
          "assigned_to_id" => "="
        },
        :values => {
          "assigned_to_id" => ["me"]
        },
        :query => {
          "name" => "test_new_global_query"
        }
      }

    q = Query.find_by_name('test_new_global_query')
    assert_redirected_to :controller => 'issues', :action => 'index', :project_id => nil, :query_id => q
    assert !q.is_public?
    assert !q.has_filter?(:status_id)
    assert_equal ['assigned_to_id'], q.filters.keys
    assert q.valid?
  end

  def test_create_with_sort
    @request.session[:user_id] = 1
    post :create, :params => {
        :default_columns => '1',
        :operators => {
          "status_id" => "o"
        },
        :values => {
          "status_id" => ["1"]
        },
        :query => {
          :name => "test_new_with_sort",
          :visibility => "2",
          :sort_criteria => {
          "0" => ["due_date", "desc"], "1" => ["tracker", ""]}
        }
      }

    query = Query.find_by_name("test_new_with_sort")
    assert_not_nil query
    assert_equal [['due_date', 'desc'], ['tracker', 'asc']], query.sort_criteria
  end

  def test_create_with_failure
    @request.session[:user_id] = 2
    assert_no_difference '::Query.count' do
      post :create, :params => {
          :project_id => 'ecookbook',
          :query => {
            :name => ''
          }
        }
    end
    assert_response :success

    assert_select 'input[name=?]', 'query[name]'
  end

  def test_create_query_without_permission_should_fail
    Role.all.each {|r| r.remove_permission! :save_queries, :manage_public_queries}

    @request.session[:user_id] = 2
    assert_no_difference '::Query.count' do
      post :create, :params => {
          :project_id => 'ecookbook',
          :query => {:name => 'Foo'}
        }
    end
    assert_response 403
  end

  def test_create_global_query_without_permission_should_fail
    Role.all.each {|r| r.remove_permission! :save_queries, :manage_public_queries}

    @request.session[:user_id] = 2
    assert_no_difference '::Query.count' do
      post :create, :params => {
          :query => {:name => 'Foo'}
        }
    end
    assert_response 403
  end

  def test_create_global_query_from_gantt
    @request.session[:user_id] = 1
    assert_difference 'IssueQuery.count' do
      post :create, :params => {
          :gantt => 1,
          :operators => {
            "status_id" => "o"
          },
          :values => {
            "status_id" => ["1"]
          },
          :query => {
            :name => "test_create_from_gantt",
            :draw_relations => '1',
            :draw_progress_line => '1',
            :draw_selected_columns => '1'
          }
        }
      assert_response 302
    end
    query = IssueQuery.order('id DESC').first
    assert_redirected_to "/issues/gantt?query_id=#{query.id}"
    assert_equal true, query.draw_relations
    assert_equal true, query.draw_progress_line
    assert_equal true, query.draw_selected_columns
  end

  def test_create_project_query_from_gantt
    @request.session[:user_id] = 1
    assert_difference 'IssueQuery.count' do
      post :create, :params => {
          :project_id => 'ecookbook',
          :gantt => 1,
          :operators => {
            "status_id" => "o"
          },
          :values => {
            "status_id" => ["1"]
          },
          :query => {
            :name => "test_create_from_gantt",
            :draw_relations => '0',
            :draw_progress_line => '0',
            :draw_selected_columns => '0'
          }
        }
      assert_response 302
    end
    query = IssueQuery.order('id DESC').first
    assert_redirected_to "/projects/ecookbook/issues/gantt?query_id=#{query.id}"
    assert_equal false, query.draw_relations
    assert_equal false, query.draw_progress_line
    assert_equal false, query.draw_selected_columns
  end

  def test_create_project_public_query_should_force_private_without_manage_public_queries_permission
    @request.session[:user_id] = 3
    query = new_record(Query) do
      post :create, :params => {
          :project_id => 'ecookbook',
          :query => {
            "name" => "name", "visibility" => "2"
          }
        }
      assert_response 302
    end
    assert_not_nil query.project
    assert_equal Query::VISIBILITY_PRIVATE, query.visibility
  end

  def test_create_global_public_query_should_force_private_without_manage_public_queries_permission
    @request.session[:user_id] = 3
    query = new_record(Query) do
      post :create, :params => {
          :project_id => 'ecookbook',
          :query_is_for_all => '1',
          :query => {
            "name" => "name", "visibility" => "2"
          }
        }
      assert_response 302
    end
    assert_nil query.project
    assert_equal Query::VISIBILITY_PRIVATE, query.visibility
  end

  def test_create_project_public_query_with_manage_public_queries_permission
    @request.session[:user_id] = 2
    query = new_record(Query) do
      post :create, :params => {
          :project_id => 'ecookbook',
          :query => {
            "name" => "name", "visibility" => "2"
          }
        }
      assert_response 302
    end
    assert_not_nil query.project
    assert_equal Query::VISIBILITY_PUBLIC, query.visibility
  end

  def test_create_global_public_query_should_force_private_with_manage_public_queries_permission
    @request.session[:user_id] = 2
    query = new_record(Query) do
      post :create, :params => {
          :project_id => 'ecookbook',
          :query_is_for_all => '1',
          :query => {
            "name" => "name", "visibility" => "2"
          }
        }
      assert_response 302
    end
    assert_nil query.project
    assert_equal Query::VISIBILITY_PRIVATE, query.visibility
  end

  def test_create_global_public_query_by_admin
    @request.session[:user_id] = 1
    query = new_record(Query) do
      post :create, :params => {
          :project_id => 'ecookbook',
          :query_is_for_all => '1',
          :query => {
            "name" => "name", "visibility" => "2"
          }
        }
      assert_response 302
    end
    assert_nil query.project
    assert_equal Query::VISIBILITY_PUBLIC, query.visibility
  end

  def test_create_project_public_time_entry_query
    @request.session[:user_id] = 2

    q = new_record(TimeEntryQuery) do
      post :create, :params => {
          :project_id => 'ecookbook',
          :type => 'TimeEntryQuery',
          :default_columns => '1',
          :f => ["spent_on"],
          :op => {
            "spent_on" => "="
          },
          :v => {
            "spent_on" => ["2016-07-14"]
          },
          :query => {
            "name" => "test_new_project_public_query", "visibility" => "2"
          }
        }
    end

    assert_redirected_to :controller => 'timelog', :action => 'index', :project_id => 'ecookbook', :query_id => q.id
    assert q.is_public?
    assert q.has_default_columns?
    assert q.valid?
  end

  def test_create_public_project_query
    @request.session[:user_id] = 1

    q = new_record(ProjectQuery) do
      post :create, :params => {
          :type => 'ProjectQuery',
          :default_columns => '1',
          :f => ["status"],
          :op => {
            "status" => "="
          },
          :v => {
            "status" => ['1']
          },
          :query => {
            "name" => "test_new_project_public_query", "visibility" => "2"
          }
        }
    end

    assert_redirected_to :controller => 'projects', :action => 'index', :query_id => q.id

    assert q.is_public?
    assert q.valid?
  end

  def test_edit_global_public_query
    @request.session[:user_id] = 1
    get :edit, :params => {
        :id => 4
      }
    assert_response :success

    assert_select 'input[name=?][value="2"][checked=checked]', 'query[visibility]'
    assert_select 'input[name=query_is_for_all][type=checkbox][checked=checked]'
  end

  def test_edit_global_private_query
    @request.session[:user_id] = 3
    get :edit, :params => {
        :id => 3
      }
    assert_response :success

    assert_select 'input[name=?]', 'query[visibility]', 0
    assert_select 'input[name=query_is_for_all][type=checkbox][checked=checked]'
  end

  def test_edit_project_private_query
    @request.session[:user_id] = 3
    get :edit, :params => {
        :id => 2
      }
    assert_response :success

    assert_select 'input[name=?]', 'query[visibility]', 0
    assert_select 'input[name=query_is_for_all][type=checkbox]:not([checked])'
  end

  def test_edit_project_public_query
    @request.session[:user_id] = 2
    get :edit, :params => {
        :id => 1
      }
    assert_response :success

    assert_select 'input[name=?][value="2"][checked=checked]', 'query[visibility]'
    assert_select 'input[name=query_is_for_all][type=checkbox]:not([checked])'
  end

  def test_edit_sort_criteria
    @request.session[:user_id] = 1
    get :edit, :params => {
        :id => 5
      }
    assert_response :success

    assert_select 'select[name=?]', 'query[sort_criteria][0][]' do
      assert_select 'option[value=priority][selected=selected]'
      assert_select 'option[value=desc][selected=selected]'
    end
  end

  def test_edit_invalid_query
    @request.session[:user_id] = 2
    get :edit, :params => {
        :id => 99
      }
    assert_response 404
  end

  def test_update_global_private_query
    @request.session[:user_id] = 3
    put :update, :params => {
        :id => 3,
        :default_columns => '1',
        :fields => ["status_id", "assigned_to_id"],
        :operators => {
          "assigned_to_id" => "=", "status_id" => "o"
        },
        :values => {
          "assigned_to_id" => ["me"], "status_id" => ["1"]
        },
        :query => {
          "name" => "test_edit_global_private_query", "visibility" => "2"
        }
      }

    assert_redirected_to :controller => 'issues', :action => 'index', :query_id => 3
    q = Query.find_by_name('test_edit_global_private_query')
    assert !q.is_public?
    assert q.has_default_columns?
    assert q.valid?
  end

  def test_update_global_public_query
    @request.session[:user_id] = 1
    put :update, :params => {
        :id => 4,
        :default_columns => '1',
        :fields => ["status_id", "assigned_to_id"],
        :operators => {
          "assigned_to_id" => "=", "status_id" => "o"
        },
        :values => {
          "assigned_to_id" => ["1"], "status_id" => ["1"]
        },
        :query => {
          "name" => "test_edit_global_public_query", "visibility" => "2"
        }
      }

    assert_redirected_to :controller => 'issues', :action => 'index', :query_id => 4
    q = Query.find_by_name('test_edit_global_public_query')
    assert q.is_public?
    assert q.has_default_columns?
    assert q.valid?
  end

  def test_update_with_failure
    @request.session[:user_id] = 1
    put :update, :params => {
        :id => 4,
        :query => {
          :name => ''
        }
      }
    assert_response :success
    assert_select_error /Name cannot be blank/
  end

  def test_destroy
    @request.session[:user_id] = 2
    delete :destroy, :params => {
        :id => 1
      }
    assert_redirected_to :controller => 'issues', :action => 'index', :project_id => 'ecookbook', :set_filter => 1, :query_id => nil
    assert_nil Query.find_by_id(1)
  end

  def test_backslash_should_be_escaped_in_filters
    @request.session[:user_id] = 2
    get :new, :params => {
        :subject => 'foo/bar'
      }
    assert_response :success
    assert_include 'addFilter("subject", "=", ["foo\/bar"]);', response.body
  end

  def test_filter_with_project_id_should_return_filter_values
    @request.session[:user_id] = 2
    get :filter, :params => {
        :project_id => 1,
        :name => 'fixed_version_id'
      }

    assert_response :success
    assert_equal 'application/json', response.content_type
    json = ActiveSupport::JSON.decode(response.body)
    assert_include ["eCookbook - 2.0", "3", "open"], json
  end

  def test_version_filter_time_entries_with_project_id_should_return_filter_values
    @request.session[:user_id] = 2
    get :filter, :params => {
        :project_id => 1,
        :type => 'TimeEntryQuery',
        :name => 'issue.fixed_version_id'
      }

    assert_response :success
    assert_equal 'application/json', response.content_type
    json = ActiveSupport::JSON.decode(response.body)
    assert_include ["eCookbook - 2.0", "3", "open"], json
  end

  def test_version_filter_without_project_id_should_return_all_visible_fixed_versions
    # Remove "jsmith" user from "Private child of eCookbook" project
    Project.find(5).memberships.find_by(:user_id => 2).destroy

    @request.session[:user_id] = 2
    get :filter, :params => {
        :name => 'fixed_version_id'
      }

    assert_response :success
    assert_equal 'application/json', response.content_type
    json = ActiveSupport::JSON.decode(response.body)

    # response includes visible version
    assert_include ["eCookbook Subproject 1 - 2.0", "4", "open"], json
    assert_include ["eCookbook - 0.1", "1", "closed"], json
    # response includes systemwide visible version
    assert_include ["OnlineStore - Systemwide visible version", "7", "open"], json
    # response doesn't include non visible version
    assert_not_include ["Private child of eCookbook - Private Version of public subproject", "6", "open"], json
  end

  def test_subproject_filter_time_entries_with_project_id_should_return_filter_values
    @request.session[:user_id] = 2
    get :filter, :params => {
        :project_id => 1,
        :type => 'TimeEntryQuery',
        :name => 'subproject_id'
      }

    assert_response :success
    assert_equal 'application/json', response.content_type
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal 4, json.count
    assert_include ["Private child of eCookbook","5"], json
  end

  def test_assignee_filter_should_return_active_and_locked_users_grouped_by_status
    @request.session[:user_id] = 1
    get :filter, :params => {
        :project_id => 1,
        :type => 'IssueQuery',
        :name => 'assigned_to_id'
      }
    assert_response :success
    assert_equal 'application/json', response.content_type
    json = ActiveSupport::JSON.decode(response.body)

    assert_equal 6, json.count
    # "me" value should not be grouped
    assert_include ["<< me >>", "me"], json
    assert_include ["Dave Lopper", "3", "active"], json
    assert_include ["Dave2 Lopper2", "5", "locked"], json
  end

  def test_author_filter_should_return_active_and_locked_users_grouped_by_status
    @request.session[:user_id] = 1
    get :filter, :params => {
        :project_id => 1,
        :type => 'IssueQuery',
        :name => 'author_id'
      }
    assert_response :success
    assert_equal 'application/json', response.content_type
    json = ActiveSupport::JSON.decode(response.body)

    assert_equal 7, json.count
    # "me" value should not be grouped
    assert_include ["<< me >>", "me"], json
    assert_include ["Dave Lopper", "3", "active"], json
    assert_include ["Dave2 Lopper2", "5", "locked"], json
    assert_include ["Anonymous", User.anonymous.id.to_s], json
  end

  def test_user_filter_should_return_active_and_locked_users_grouped_by_status
    @request.session[:user_id] = 1
    get :filter, :params => {
        :project_id => 1,
        :type => 'TimeEntryQuery',
        :name => 'user_id'
      }
    assert_response :success
    assert_equal 'application/json', response.content_type
    json = ActiveSupport::JSON.decode(response.body)

    assert_equal 7, json.count
    # "me" value should not be grouped
    assert_include ["<< me >>", "me"], json
    assert_include ["Dave Lopper", "3", "active"], json
    assert_include ["Dave2 Lopper2", "5", "locked"], json
  end

  def test_watcher_filter_without_permission_should_show_only_me
    # This user does not have view_issue_watchers permission
    @request.session[:user_id] = 7

    get :filter, :params => {
        :project_id => 1,
        :type => 'IssueQuery',
        :name => 'watcher_id'
      }
    assert_response :success
    assert_equal 'application/json', response.content_type
    json = ActiveSupport::JSON.decode(response.body)

    assert_equal 1, json.count
    assert_equal [["<< me >>", "me"]], json
  end

  def test_watcher_filter_with_permission_should_show_members
    # This user has view_issue_watchers permission
    @request.session[:user_id] = 1

    get :filter, :params => {
        :project_id => 1,
        :type => 'IssueQuery',
        :name => 'watcher_id'
      }
    assert_response :success
    assert_equal 'application/json', response.content_type
    json = ActiveSupport::JSON.decode(response.body)

    assert_equal 6, json.count
    # "me" value should not be grouped
    assert_include ["<< me >>", "me"], json
    assert_include ["Dave Lopper", "3", "active"], json
    assert_include ["Dave2 Lopper2", "5", "locked"], json
  end
end
