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

class ProjectsControllerTest < Redmine::ControllerTest
  fixtures :projects, :versions, :users, :email_addresses, :roles, :members,
           :member_roles, :issues, :journals, :journal_details,
           :trackers, :projects_trackers, :issue_statuses,
           :enabled_modules, :enumerations, :boards, :messages,
           :attachments, :custom_fields, :custom_values, :time_entries,
           :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions

  include Redmine::I18n

  def setup
    @request.session[:user_id] = nil
    Setting.default_language = 'en'
  end

  def test_index_by_anonymous_should_not_show_private_projects
    get :index
    assert_response :success

    assert_select 'ul' do
      assert_select 'li' do
        assert_select 'a', :text => 'eCookbook'
        assert_select 'ul' do
          assert_select 'a', :text => 'Child of private child'
        end
      end
    end
    assert_select 'a', :text => /Private child of eCookbook/, :count => 0
  end

  def test_index_atom
    get :index, :params => {
        :format => 'atom'
      }
    assert_response :success
    assert_select 'feed>title', :text => 'Redmine: Latest projects'
    assert_select 'feed>entry', :count => Project.visible(User.current).count
  end

  def test_index_with_project_filter_is_my_projects
    @request.session[:user_id] = 2

    get :index, :params => {
      :f => ['id'],
      :op => {'id' => '='},
      :v => {'id' => ['mine']}
    }

    assert_response :success

    assert_select 'div#projects-index ul' do
      assert_select 'a.project',  3
      assert_select 'a', :text => 'eCookbook'
      assert_select 'a', :text => 'OnlineStore'
      assert_select 'a', :text => 'Private child of eCookbook'
    end
  end

  def test_index_with_subproject_filter
    @request.session[:user_id] = 1

    get :index, :params => {
      :f => ['parent_id'],
      :op => {'parent_id' => '='},
      :v => {'parent_id' => ['1']}
    }

    assert_response :success

    assert_select 'div#projects-index ul' do
      assert_select 'a.project',  3
      assert_select 'a', :text => 'eCookbook Subproject 1'
      assert_select 'a', :text => 'eCookbook Subproject 2'
      assert_select 'a', :text => 'Private child of eCookbook'
    end
  end

  def test_index_as_list_should_format_column_value
    get :index, :params => {
      :c => ['name', 'status', 'short_description', 'homepage', 'parent_id', 'identifier', 'is_public', 'created_on', 'cf_3'],
      :display_type => 'list'
    }
    assert_response :success

    project = Project.find(1)
    assert_select 'table.projects' do
      assert_select 'tr[id=?]', 'project-1' do
        assert_select 'td.name a[href=?]', '/projects/ecookbook', :text => 'eCookbook'
        assert_select 'td.status', :text => 'active'
        assert_select 'td.short_description', :text => 'Recipes management application'
        assert_select 'td.homepage a.external', :text => 'http://ecookbook.somenet.foo/'
        assert_select 'td.identifier', :text => 'ecookbook'
        assert_select 'td.is_public', :text => 'Yes'
        assert_select 'td.created_on', :text => format_time(project.created_on)
        assert_select 'td.cf_3.list', :text => 'Stable'
      end
      assert_select 'tr[id=?]', 'project-4' do
        assert_select 'td.parent_id a[href=?]', '/projects/ecookbook', :text => 'eCookbook'
      end
    end
  end

  def test_index_as_list_should_show_my_favourite_projects
    @request.session[:user_id] = 1
    get :index, :params => {
      :display_type => 'list'
    }

    assert_response :success
    assert_select 'tr[id=?] td.name span[class=?]', 'project-5', 'icon icon-user my-project'
  end

  def test_index_as_list_should_indent_projects
    @request.session[:user_id] = 1
    get :index, :params => {
      :c => ['name', 'short_description'],
      :sort => 'parent_id:desc,lft:desc',
      :display_type => 'list'
    }
    assert_response :success

    child_level1 = css_select('tr#project-5').map {|e| e.attr('class')}.first.split(' ')
    child_level2 = css_select('tr#project-6').map {|e| e.attr('class')}.first.split(' ')

    assert_include 'idnt', child_level1
    assert_include 'idnt-1', child_level1

    assert_include 'idnt', child_level2
    assert_include 'idnt-2', child_level2
  end

  def test_index_with_default_query_setting
    with_settings :project_list_defaults => {'column_names' => %w(name short_description status)} do
      get :index, :params => {
        :display_type => 'list'
      }
      assert_response :success
    end
    assert_equal ['Name', 'Description', 'Status'], columns_in_list
  end

  def test_index_as_board_should_not_include_csv_export
    @request.session[:user_id] = 1

    get :index

    assert_response :success
    assert_select 'p.other-formats a.csv', 0
    assert_select '#csv-export-options', 0
  end

  def test_index_as_list_should_include_csv_export
    @request.session[:user_id] = 1

    get :index, :params => {
      :display_type => 'list',
      :f => ['parent_id'],
      :op => {'parent_id' => '='},
      :v => {'parent_id' => ['1']}
    }
    assert_response :success

    # Assert CSV export link
    assert_select 'p.other-formats a.csv'

    # Assert export modal
    assert_select '#csv-export-options' do
      assert_select 'form[action=?][method=get]', '/projects.csv' do
        # filter
        assert_select 'input[name=?][value=?]', 'f[]', 'parent_id'
        assert_select 'input[name=?][value=?]', 'op[parent_id]', '='
        assert_select 'input[name=?][value=?]', 'v[parent_id][]', '1'
        # columns
        assert_select 'input[name=?][type=hidden][value=?]', 'c[]', 'name'
        assert_select 'input[name=?][type=hidden][value=?]', 'c[]', 'identifier'
        assert_select 'input[name=?][type=hidden][value=?]', 'c[]', 'short_description'
        assert_select 'input[name=?][type=hidden]', 'c[]', 3
        assert_select 'input[name=?][value=?]', 'c[]', 'all_inline'
      end
    end
  end

  def test_index_csv
    with_settings :date_format => '%m/%d/%Y' do
      get :index, :params => {:format => 'csv'}
      assert_response :success
      assert_equal 'text/csv', response.media_type
    end
  end

  def test_index_sort_by_custom_field
    @request.session[:user_id] = 1

    cf = ProjectCustomField.find(3)
    CustomValue.create!(:custom_field => cf, :customized => Project.find(2), :value => 'Beta')

    get(
      :index,
      :params => {
        :display_type => 'list',
        :c => ['name', 'identifier', 'cf_3'],
        :set_filter => 1,
        :sort => "cf_#{cf.id}:asc"
      }
    )
    assert_response :success

    assert_equal(
      ['Beta', 'Stable'],
      columns_values_in_list('cf_3').reject {|p| p.empty?}
    )
  end

  def test_index_with_int_custom_field_total
    @request.session[:user_id] = 1

    field = ProjectCustomField.generate!(:field_format => 'int')
    CustomValue.create!(:customized => Project.find(1), :custom_field => field, :value => '2')
    CustomValue.create!(:customized => Project.find(2), :custom_field => field, :value => '7')
    get(
      :index,
      :params => {
        :display_type => 'list',
        :t => ["cf_#{field.id}"]
      }
    )
    assert_response :success
    assert_select '.query-totals'
    assert_select ".total-for-cf-#{field.id} span.value", :text => '9'
  end

  def test_autocomplete_js
    get :autocomplete, :params => {
        :format => 'js',
        :q => 'coo'
      },
      :xhr => true
    assert_response :success
    assert_equal 'text/javascript', response.content_type
  end

  def test_autocomplete_js_with_blank_search_term
    get :autocomplete, :params => {
        :format => 'js',
        :q => ''
      },
      :xhr => true
    assert_response :success
    assert_equal 'text/javascript', response.content_type
  end

  test "#index by non-admin user with view_time_entries permission should show overall spent time link" do
    @request.session[:user_id] = 3
    get :index
    assert_select 'a[href=?]', '/time_entries'
  end

  test "#index by non-admin user without view_time_entries permission should not show overall spent time link" do
    Role.find(2).remove_permission! :view_time_entries
    Role.non_member.remove_permission! :view_time_entries
    Role.anonymous.remove_permission! :view_time_entries
    @request.session[:user_id] = 3

    get :index
    assert_select 'a[href=?]', '/time_entries', 0
  end

  test "#index by non-admin user with permission should show add project link" do
    Role.find(1).add_permission! :add_project
    @request.session[:user_id] = 2

    get :index
    assert_select 'a[href=?]', '/projects/new'
  end

  test "#new by admin user should accept get" do
    @request.session[:user_id] = 1

    get :new
    assert_response :success
    assert_select 'input[name=?]', 'project[name]'
    assert_select 'select[name=?]', 'project[parent_id]'
  end

  test "#new by non-admin user with add_project permission should accept get" do
    Role.non_member.add_permission! :add_project
    @request.session[:user_id] = 9

    get :new
    assert_response :success
    assert_select 'input[name=?]', 'project[name]'
    assert_select 'select[name=?]', 'project[parent_id]', 0
  end

  test "#new by non-admin user with add_subprojects permission should accept get" do
    Role.find(1).remove_permission! :add_project
    Role.find(1).add_permission! :add_subprojects
    @request.session[:user_id] = 2

    get :new, :params => {
        :parent_id => 'ecookbook'
      }
    assert_response :success

    assert_select 'select[name=?]', 'project[parent_id]' do
      # parent project selected
      assert_select 'option[value="1"][selected=selected]'
      # no empty value
      assert_select 'option[value=""]', 0
    end
  end

  def test_new_by_non_admin_should_display_modules_if_default_role_is_allowed_to_select_modules
    Role.non_member.add_permission!(:add_project)
    default_role = Role.generate!(:permissions => [:view_issues])
    user = User.generate!
    @request.session[:user_id] = user.id

    with_settings :new_project_user_role_id => default_role.id.to_s do
      get :new
      assert_select 'input[name=?]', 'project[enabled_module_names][]', 0

      default_role.add_permission!(:select_project_modules)
      get :new
      assert_select 'input[name=?]', 'project[enabled_module_names][]'
    end
  end

  def test_new_should_not_display_invalid_search_link
    @request.session[:user_id] = 1

    get :new
    assert_response :success
    assert_select '#quick-search form[action=?]', '/search'
    assert_select '#quick-search a[href=?]', '/search'
  end

  test "#create by admin user should create a new project" do
    @request.session[:user_id] = 1

    post :create, :params => {
        :project => {
          :name => "blog",
          :description => "weblog",
          :homepage => 'http://weblog',
          :identifier => "blog",
          :is_public => 1,
          :custom_field_values => {
            '3' => 'Beta'
          },
          :tracker_ids => ['1', '3'],
          # an issue custom field that is not for all project
          :issue_custom_field_ids => ['9'],
          :enabled_module_names => ['issue_tracking', 'news', 'repository']
        }
      }
    assert_redirected_to '/projects/blog/settings'

    project = Project.find_by_name('blog')
    assert_kind_of Project, project
    assert project.active?
    assert_equal 'weblog', project.description
    assert_equal 'http://weblog', project.homepage
    assert_equal true, project.is_public?
    assert_nil project.parent
    assert_equal 'Beta', project.custom_value_for(3).value
    assert_equal [1, 3], project.trackers.map(&:id).sort
    assert_equal ['issue_tracking', 'news', 'repository'], project.enabled_module_names.sort
    assert project.issue_custom_fields.include?(IssueCustomField.find(9))
  end

  test "#create by admin user should create a new subproject" do
    @request.session[:user_id] = 1

    assert_difference 'Project.count' do
      post :create, :params => {
          :project => {
            :name => "blog",
            :description => "weblog",
            :identifier => "blog",
            :is_public => 1,
            :custom_field_values => {
              '3' => 'Beta'
            },
            :parent_id => 1

          }
        }
      assert_redirected_to '/projects/blog/settings'
    end

    project = Project.find_by_name('blog')
    assert_kind_of Project, project
    assert_equal Project.find(1), project.parent
  end

  test "#create by admin user should continue" do
    @request.session[:user_id] = 1

    assert_difference 'Project.count' do
      post :create, :params => {
          :project => {
            :name => "blog",
            :identifier => "blog"
          },
          :continue => 'Create and continue'
        }
    end
    assert_redirected_to '/projects/new'
  end

  test "#create by non-admin user with add_project permission should create a new project" do
    Role.non_member.add_permission! :add_project
    @request.session[:user_id] = 9

    post :create, :params => {
        :project => {
          :name => "blog",
          :description => "weblog",
          :identifier => "blog",
          :is_public => 1,
          :custom_field_values => {
            '3' => 'Beta'
          },
          :tracker_ids => ['1', '3'],
          :enabled_module_names => ['issue_tracking', 'news', 'repository']

        }
      }

    assert_redirected_to '/projects/blog/settings'

    project = Project.find_by_name('blog')
    assert_kind_of Project, project
    assert_equal 'weblog', project.description
    assert_equal true, project.is_public?
    assert_equal [1, 3], project.trackers.map(&:id).sort
    assert_equal ['issue_tracking', 'news', 'repository'], project.enabled_module_names.sort

    # User should be added as a project member
    assert User.find(9).member_of?(project)
    assert_equal 1, project.members.size
  end

  test "#create by non-admin user with add_project permission should fail with parent_id" do
    Role.non_member.add_permission! :add_project
    User.find(9).update! :language => 'en'
    @request.session[:user_id] = 9

    assert_no_difference 'Project.count' do
      post :create, :params => {
          :project => {
            :name => "blog",
            :description => "weblog",
            :identifier => "blog",
            :is_public => 1,
            :custom_field_values => {
              '3' => 'Beta'
            },
            :parent_id => 1

          }
        }
    end
    assert_response :success
    assert_select_error /Subproject of is invalid/
  end

  test "#create by non-admin user with add_subprojects permission should create a project with a parent_id" do
    Role.find(1).remove_permission! :add_project
    Role.find(1).add_permission! :add_subprojects
    @request.session[:user_id] = 2

    post :create, :params => {
        :project => {
          :name => "blog",
          :description => "weblog",
          :identifier => "blog",
          :is_public => 1,
          :custom_field_values => {
            '3' => 'Beta'
          },
          :parent_id => 1

        }
      }
    assert_redirected_to '/projects/blog/settings'
    project = Project.find_by_name('blog')
    assert_equal 1, project.parent_id
  end

  test "#create by non-admin user with add_subprojects permission should fail without parent_id" do
    Role.find(1).remove_permission! :add_project
    Role.find(1).add_permission! :add_subprojects
    @request.session[:user_id] = 2

    assert_no_difference 'Project.count' do
      post :create, :params => {
          :project => {
            :name => "blog",
            :description => "weblog",
            :identifier => "blog",
            :is_public => 1,
            :custom_field_values => {
              '3' => 'Beta'
            }

          }
        }
    end
    assert_response :success
    assert_select_error /Subproject of is invalid/
  end

  test "#create by non-admin user with add_subprojects permission should fail with unauthorized parent_id" do
    Role.find(1).remove_permission! :add_project
    Role.find(1).add_permission! :add_subprojects
    @request.session[:user_id] = 2

    assert !User.find(2).member_of?(Project.find(6))
    assert_no_difference 'Project.count' do
      post :create, :params => {
          :project => {
            :name => "blog",
            :description => "weblog",
            :identifier => "blog",
            :is_public => 1,
            :custom_field_values => {
              '3' => 'Beta'
            },
            :parent_id => 6

          }
        }
    end
    assert_response :success
    assert_select_error /Subproject of is invalid/
  end

  def test_create_by_non_admin_should_accept_modules_if_default_role_is_allowed_to_select_modules
    Role.non_member.add_permission!(:add_project)
    default_role = Role.generate!(:permissions => [:view_issues, :add_project])
    user = User.generate!
    @request.session[:user_id] = user.id

    with_settings :new_project_user_role_id => default_role.id.to_s, :default_projects_modules => %w(news files) do
      project = new_record(Project) do
        post :create, :params => {
            :project => {
              :name => "blog1",
              :identifier => "blog1",
              :enabled_module_names => ["issue_tracking", "repository"]

            }
          }
      end
      assert_equal %w(files news), project.enabled_module_names.sort

      default_role.add_permission!(:select_project_modules)
      project = new_record(Project) do
        post :create, :params => {
            :project => {
              :name => "blog2",
              :identifier => "blog2",
              :enabled_module_names => ["issue_tracking", "repository"]

            }
          }
      end
      assert_equal %w(issue_tracking repository), project.enabled_module_names.sort
    end
  end

  def test_create_subproject_with_inherit_members_should_inherit_members
    Role.find_by_name('Manager').add_permission! :add_subprojects
    parent = Project.find(1)
    @request.session[:user_id] = 2

    assert_difference 'Project.count' do
      post :create, :params => {
          :project => {
            :name => 'inherited',
            :identifier => 'inherited',
            :parent_id => parent.id,
            :inherit_members => '1'

          }
        }
      assert_response 302
    end

    project = Project.order('id desc').first
    assert_equal 'inherited', project.name
    assert_equal parent, project.parent
    assert project.memberships.count > 0
    assert_equal parent.memberships.count, project.memberships.count
  end

  def test_create_should_preserve_modules_on_validation_failure
    with_settings :default_projects_modules => ['issue_tracking', 'repository'] do
      @request.session[:user_id] = 1
      assert_no_difference 'Project.count' do
        post :create, :params => {
            :project => {
              :name => "blog",
              :identifier => "",
              :enabled_module_names => %w(issue_tracking news)

            }
          }
      end
      assert_response :success
      %w(issue_tracking news).each do |mod|
        assert_select 'input[name=?][value=?][checked=checked]', 'project[enabled_module_names][]', mod
      end
      assert_select 'input[name=?][checked=checked]', 'project[enabled_module_names][]', :count => 2
    end
  end

  def test_show_by_id
    get :show, :params => {
        :id => 1
      }
    assert_response :success
    assert_select '#header h1', :text => "eCookbook"
  end

  def test_show_by_identifier
    get :show, :params => {
        :id => 'ecookbook'
      }
    assert_response :success
    assert_select '#header h1', :text => "eCookbook"
  end

  def test_show_should_not_display_empty_sidebar
    p = Project.find(1)
    p.enabled_module_names = []
    p.save!

    get :show, :params => {
        :id => 'ecookbook'
      }
    assert_response :success
    assert_select '#main.nosidebar'
  end

  def test_show_should_display_visible_custom_fields
    ProjectCustomField.find_by_name('Development status').update_attribute :visible, true
    get :show, :params => {
        :id => 'ecookbook'
      }
    assert_response :success

    assert_select 'li[class=?]', 'cf_3', :text => /Development status/
  end

  def test_show_should_not_display_hidden_custom_fields
    ProjectCustomField.find_by_name('Development status').update_attribute :visible, false
    get :show, :params => {
        :id => 'ecookbook'
      }
    assert_response :success

    assert_select 'li', :text => /Development status/, :count => 0
  end

  def test_show_should_not_display_blank_custom_fields_with_multiple_values
    f1 = ProjectCustomField.generate! :field_format => 'list', :possible_values => %w(Foo Bar), :multiple => true
    f2 = ProjectCustomField.generate! :field_format => 'list', :possible_values => %w(Baz Qux), :multiple => true
    project = Project.generate!(:custom_field_values => {f2.id.to_s => %w(Qux)})

    get :show, :params => {
        :id => project.id
      }
    assert_response :success

    assert_select 'li', :text => /#{f1.name}/, :count => 0
    assert_select 'li', :text => /#{f2.name}/
  end

  def test_show_should_not_display_blank_text_custom_fields
    f1 = ProjectCustomField.generate! :field_format => 'text'

    get :show, :params => {
        :id => 1
      }
    assert_response :success

    assert_select 'li', :text => /#{f1.name}/, :count => 0
  end

  def test_show_should_not_fail_when_custom_values_are_nil
    project = Project.find_by_identifier('ecookbook')
    project.custom_values.first.update_attribute(:value, nil)
    get :show, :params => {
        :id => 'ecookbook'
      }
    assert_response :success
  end

  def test_show_archived_project_should_be_denied
    project = Project.find_by_identifier('ecookbook')
    project.archive

    get :show, :params => {
        :id => 'ecookbook'
      }
    assert_response 403
    assert_select 'p', :text => /archived/
    assert_not_include project.name, response.body
  end

  def test_show_archived_project_should_show_unarchive_link_to_admins
    @request.session[:user_id] = 1
    project = Project.find_by_identifier('ecookbook')
    project.archive

    get :show, :params => {
        :id => 'ecookbook'
      }
    assert_response 403
    assert_select 'a', :text => "Unarchive"
  end

  def test_show_should_not_show_private_subprojects_that_are_not_visible
    get :show, :params => {
        :id => 'ecookbook'
      }
    assert_response :success
    assert_select 'a', :text => /Private child/, :count => 0
  end

  def test_show_should_show_private_subprojects_that_are_visible
    @request.session[:user_id] = 2 # manager who is a member of the private subproject
    get :show, :params => {
        :id => 'ecookbook'
      }
    assert_response :success
    assert_select 'a', :text => /Private child/
  end

  def test_show_by_member_on_leaf_project_should_display_issue_counts
    @request.session[:user_id] = 2
    get :show, :params => {
        :id => 'onlinestore'
      }
    assert_response :success
    # Make sure there's a > 0 issue count
    assert_select 'table.issue-report td.total a', :text => %r{\A[1-9]\d*\z}
  end

  def test_show_should_spent_and_estimated_time
    @request.session[:user_id] = 1
    get :show, :params => {
        :id => 'ecookbook'
      }

    assert_select 'div.spent_time.box>ul' do
      assert_select '>li:nth-child(1)', :text => 'Estimated time: 203.50 hours'
      assert_select '>li:nth-child(2)', :text => 'Spent time: 162.90 hours'
    end
  end

  def test_settings
    @request.session[:user_id] = 2 # manager
    get :settings, :params => {
        :id => 1
      }
    assert_response :success

    assert_select 'input[name=?]', 'project[name]'
  end

  def test_settings_of_subproject
    @request.session[:user_id] = 2
    get :settings, :params => {
        :id => 'private-child'
      }
    assert_response :success

    assert_select 'input[type=checkbox][name=?]', 'project[inherit_members]'
  end

  def test_settings_should_be_denied_for_member_on_closed_project
    Project.find(1).close
    @request.session[:user_id] = 2 # manager

    get :settings, :params => {
        :id => 1
      }
    assert_response 403
  end

  def test_settings_should_be_denied_for_anonymous_on_closed_project
    Project.find(1).close

    get :settings, :params => {
        :id => 1
      }
    assert_response 403
  end

  def test_settings_should_accept_version_status_filter
    @request.session[:user_id] = 2

    get :settings, :params => {
        :id => 'ecookbook',
        :tab => 'versions',
        :version_status => 'locked'
      }
    assert_response :success

    assert_select 'select[name=version_status]' do
      assert_select 'option[value=locked][selected=selected]'
    end
    assert_select 'table.versions tbody' do
      assert_select 'tr', 1
      assert_select 'td.name', :text => '1.0'
    end
    assert_select 'a#tab-versions[href=?]', '/projects/ecookbook/settings/versions?version_status=locked'
  end

  def test_settings_should_accept_version_name_filter
    @request.session[:user_id] = 2

    get :settings, :params => {
        :id => 'ecookbook',
        :tab => 'versions',
        :version_status => '',
        :version_name => '.1'
      }
    assert_response :success

    assert_select 'input[name=version_name][value=?]', '.1'
    assert_select 'table.versions tbody' do
      assert_select 'tr', 1
      assert_select 'td.name', :text => '0.1'
    end
    assert_select 'a#tab-versions[href=?]', '/projects/ecookbook/settings/versions?version_name=.1&version_status='
  end

  def test_settings_should_show_default_version_in_versions_tab
    project = Project.find(1)
    project.default_version_id = 3
    project.save!

    @request.session[:user_id] = 2

    get :settings, :params => {
        :id => 'ecookbook',
        :tab => 'versions',
      }
    assert_response :success

    assert_select 'table.versions tbody' do
      # asserts that only one version is marked as default
      assert_select 'td.tick span.icon-checked', 1
      # asserts which version is marked as default
      assert_select 'tr:first-child td.tick span.icon-checked', 1
    end
  end

  def test_settings_should_show_locked_members
    user = User.generate!
    member = User.add_to_project(user, Project.find(1))
    user.lock!
    assert user.reload.locked?
    @request.session[:user_id] = 2

    get :settings, :params => {
        :id => 'ecookbook',
        :tab => 'members'
      }
    assert_response :success
    assert_select "tr#member-#{member.id}"
  end

  def test_settings_should_show_tabs_depending_on_permission
    @request.session[:user_id] = 3
    project = Project.find(1)
    role = User.find(3).roles_for_project(project).first

    role.permissions = []
    role.save
    get :settings, :params => {
      :id => project.id
    }
    assert_response 403

    role.add_permission! :manage_repository, :manage_boards, :manage_project_activities
    get :settings, :params => {
      :id => project.id
    }
    assert_response :success
    assert_select 'a[id^=tab-]', 3
    assert_select 'a#tab-repositories'
    assert_select 'a#tab-boards'
    assert_select 'a#tab-activities'
  end

  def test_settings_should_not_display_custom_fields_not_visible_for_user
    @request.session[:user_id] = 2

    ProjectCustomField.find_by_name('Development status').update_attribute :visible, false
    get :settings, :params => {
        :id => 'ecookbook'
      }
    assert_response :success

    assert_select 'select#project_custom_field_values_3', :count => 0
  end

  def test_update
    @request.session[:user_id] = 2 # manager
    post :update, :params => {
        :id => 1,
        :project => {
          :name => 'Test changed name',
          :issue_custom_field_ids => ['']
        }
      }
    assert_redirected_to '/projects/ecookbook/settings'
    project = Project.find(1)
    assert_equal 'Test changed name', project.name
  end

  def test_update_with_failure
    @request.session[:user_id] = 2 # manager
    post :update, :params => {
        :id => 1,
        :project => {
          :name => ''
        }
      }
    assert_response :success
    assert_select_error /name cannot be blank/i
  end

  def test_update_should_be_denied_for_member_on_closed_project
    Project.find(1).close
    @request.session[:user_id] = 2 # manager

    post :update, :params => {
        :id => 1,
        :project => {
          :name => 'Closed'
        }
      }
    assert_response 403
    assert_equal 'eCookbook', Project.find(1).name
  end

  def test_update_should_be_denied_for_anonymous_on_closed_project
    Project.find(1).close

    post :update, :params => {
        :id => 1,
        :project => {
          :name => 'Closed'
        }
      }
    assert_response 403
    assert_equal 'eCookbook', Project.find(1).name
  end

  def test_update_child_project_without_parent_permission_should_not_show_validation_error
    child = Project.generate_with_parent!
    user = User.generate!
    User.add_to_project(user, child, Role.generate!(:permissions => [:edit_project]))
    @request.session[:user_id] = user.id

    post :update, :params => {
        :id => child.id,
        :project => {
          :name => 'Updated'
        }
      }
    assert_response 302
    assert_match /Successful update/, flash[:notice]
  end

  def test_update_modules
    @request.session[:user_id] = 2
    Project.find(1).enabled_module_names = ['issue_tracking', 'news']

    post :update, :params => {
        :id => 1,
        :project => {
          :enabled_module_names => ['issue_tracking', 'repository', 'documents']
        }
      }
    assert_redirected_to '/projects/ecookbook/settings'
    assert_equal ['documents', 'issue_tracking', 'repository'], Project.find(1).enabled_module_names.sort
  end

  def test_destroy_leaf_project_without_confirmation_should_show_confirmation
    @request.session[:user_id] = 1 # admin

    assert_no_difference 'Project.count' do
      delete :destroy, :params => {
          :id => 2
        }
      assert_response :success
    end
    assert_select '.warning', :text => /Are you sure you want to delete this project/
  end

  def test_destroy_without_confirmation_should_show_confirmation_with_subprojects
    set_tmp_attachments_directory
    @request.session[:user_id] = 1 # admin

    assert_no_difference 'Project.count' do
      delete :destroy, :params => {
          :id => 1
        }
      assert_response :success
    end
    assert_select 'strong',
                  :text => ['Private child of eCookbook',
                            'Child of private child, eCookbook Subproject 1',
                            'eCookbook Subproject 2'].join(', ')
  end

  def test_destroy_with_confirmation_should_destroy_the_project_and_subprojects
    set_tmp_attachments_directory
    @request.session[:user_id] = 1 # admin

    assert_difference 'Project.count', -5 do
      delete :destroy, :params => {
          :id => 1,
          :confirm => 1
        }
      assert_redirected_to '/admin/projects'
    end
    assert_nil Project.find_by_id(1)
  end

  def test_archive
    @request.session[:user_id] = 1 # admin
    post :archive, :params => {
        :id => 1
      }
    assert_redirected_to '/admin/projects'
    assert !Project.find(1).active?
  end

  def test_archive_with_failure
    @request.session[:user_id] = 1
    Project.any_instance.stubs(:archive).returns(false)
    post :archive, :params => {
        :id => 1
      }
    assert_redirected_to '/admin/projects'
    assert_match /project cannot be archived/i, flash[:error]
  end

  def test_unarchive
    @request.session[:user_id] = 1 # admin
    Project.find(1).archive
    post :unarchive, :params => {
        :id => 1
      }
    assert_redirected_to '/admin/projects'
    assert Project.find(1).active?
  end

  def test_close
    @request.session[:user_id] = 2
    post :close, :params => {
        :id => 1
      }
    assert_redirected_to '/projects/ecookbook'
    assert_equal Project::STATUS_CLOSED, Project.find(1).status
  end

  def test_reopen
    Project.find(1).close
    @request.session[:user_id] = 2
    post :reopen, :params => {
        :id => 1
      }
    assert_redirected_to '/projects/ecookbook'
    assert Project.find(1).active?
  end

  def test_project_breadcrumbs_should_be_limited_to_3_ancestors
    CustomField.delete_all
    parent = nil
    6.times do |i|
      p = Project.generate_with_parent!(parent)
      get :show, :params => {
          :id => p
        }
      assert_select '#header h1' do
        assert_select 'a', :count => [i, 3].min
      end

      parent = p
    end
  end

  def test_get_copy
    @request.session[:user_id] = 1 # admin
    orig = Project.find(1)

    get :copy, :params => {
        :id => orig.id
      }
    assert_response :success

    assert_select 'textarea[name=?]', 'project[description]', :text => orig.description
    assert_select 'input[name=?][value=?]', 'project[enabled_module_names][]', 'issue_tracking', 1
  end

  def test_get_copy_with_invalid_source_should_respond_with_404
    @request.session[:user_id] = 1
    get :copy, :params => {
        :id => 99
      }
    assert_response 404
  end

  def test_get_copy_should_preselect_custom_fields
    field1 = IssueCustomField.generate!(:is_for_all => false)
    field2 = IssueCustomField.generate!(:is_for_all => false)
    source = Project.generate!(:issue_custom_fields => [field1])
    @request.session[:user_id] = 1

    get :copy, :params => {
        :id => source.id
      }
    assert_response :success
    assert_select 'input[type=hidden][name=?][value=?]', 'project[issue_custom_field_ids][]', field1.id.to_s
    assert_select 'input[type=hidden][name=?][value=?]', 'project[issue_custom_field_ids][]', field2.id.to_s, 0
  end

  def test_post_copy_should_copy_requested_items
    @request.session[:user_id] = 1 # admin
    CustomField.delete_all

    assert_difference 'Project.count' do
      post :copy, :params => {
          :id => 1,
          :project => {
            :name => 'Copy',
            :identifier => 'unique-copy',
            :tracker_ids => ['1', '2', '3', ''],
            :enabled_module_names => %w(issue_tracking time_tracking)

          },
          :only => %w(issues versions)
        }
    end
    project = Project.find('unique-copy')
    source = Project.find(1)
    assert_equal %w(issue_tracking time_tracking), project.enabled_module_names.sort

    assert_equal source.versions.count, project.versions.count, "All versions were not copied"
    assert_equal source.issues.count, project.issues.count, "All issues were not copied"
    assert_equal 0, project.members.count
  end

  def test_post_copy_should_redirect_to_settings_when_successful
    @request.session[:user_id] = 1 # admin
    post :copy, :params => {
        :id => 1,
        :project => {
          :name => 'Copy',
          :identifier => 'unique-copy'
        }
      }
    assert_response :redirect
    assert_redirected_to :controller => 'projects', :action => 'settings', :id => 'unique-copy'
  end

  def test_post_copy_with_failure
    @request.session[:user_id] = 1
    post :copy, :params => {
        :id => 1,
        :project => {
          :name => 'Copy',
          :identifier => ''
        }
      }
    assert_response :success
    assert_select_error /Identifier cannot be blank/
  end

  def test_bookmark_should_create_bookmark
    @request.session[:user_id] = 3
    post :bookmark, params: { id: 'ecookbook' }
    assert_redirected_to controller: 'projects', action: 'show', id: 'ecookbook'
    jb = Redmine::ProjectJumpBox.new(User.find(3))
    assert jb.bookmark?(Project.find('ecookbook'))
    refute jb.bookmark?(Project.find('onlinestore'))
  end

  def test_bookmark_should_delete_bookmark
    @request.session[:user_id] = 3
    jb = Redmine::ProjectJumpBox.new(User.find(3))
    project = Project.find('ecookbook')
    jb.bookmark_project project
    delete :bookmark, params: { id: 'ecookbook' }
    assert_redirected_to controller: 'projects', action: 'show', id: 'ecookbook'

    jb = Redmine::ProjectJumpBox.new(User.find(3))
    refute jb.bookmark?(Project.find('ecookbook'))
  end

  def test_index_jump_without_project_id_should_redirect_to_active_tab
    get :index, :params => {
        :jump => 'issues'
      }
    assert_redirected_to '/issues'
  end

  def test_index_jump_should_not_redirect_to_unknown_tab
    get :index, :params => {
        :jump => 'foobar'
      }
    assert_response :success
  end

  def test_show_jump_should_redirect_to_active_tab
    get :show, :params => {
        :id => 1,
        :jump => 'issues'
      }
    assert_redirected_to '/projects/ecookbook/issues'
  end

  def test_show_jump_should_not_redirect_to_inactive_tab
    get :show, :params => {
        :id => 3,
        :jump => 'documents'
      }
    assert_response :success
  end

  def test_show_jump_should_not_redirect_to_unknown_tab
    get :show, :params => {
        :id => 3,
        :jump => 'foobar'
      }
    assert_response :success
  end

  def test_body_should_have_project_css_class
    get :show, :params => {
        :id => 1
      }
    assert_select 'body.project-ecookbook'
  end

  def test_default_search_scope_in_global_page
    get :index

    assert_select 'div#quick-search form' do
      assert_select 'input[name=scope][type=hidden]'
      assert_select 'a[href=?]', '/search'
    end
  end

  def test_default_search_scope_for_project_without_subprojects
    get :show, :params => {
      :id => 4,
    }

    assert_select 'div#quick-search form' do
      assert_select 'input[name=scope][type=hidden]'
      assert_select 'a[href=?]', '/projects/subproject2/search'
    end
  end

  def test_default_search_scope_for_project_with_subprojects
    get :show, :params => {
      :id => 1,
    }

    assert_select 'div#quick-search form' do
      assert_select 'input[name=scope][type=hidden][value=subprojects]'
      assert_select 'a[href=?]', '/projects/ecookbook/search?scope=subprojects'
    end
  end
end
