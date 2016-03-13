# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

require File.expand_path('../../../../test_helper', __FILE__)

class HookTest < Redmine::IntegrationTest
  fixtures :users, :roles, :projects, :members, :member_roles

  # Hooks that are manually registered later
  class ProjectBasedTemplate < Redmine::Hook::ViewListener
    def view_layouts_base_html_head(context)
      # Adds a project stylesheet
      stylesheet_link_tag(context[:project].identifier) if context[:project]
    end
  end

  class SidebarContent < Redmine::Hook::ViewListener
    def view_layouts_base_sidebar(context)
      content_tag('p', 'Sidebar hook')
    end
  end

  Redmine::Hook.clear_listeners

  class ContentForInsideHook < Redmine::Hook::ViewListener
    render_on :view_welcome_index_left, :inline => <<-VIEW
<% content_for :header_tags do %>
  <%= javascript_include_tag 'test_plugin.js', :plugin => 'test_plugin' %>
  <%= stylesheet_link_tag 'test_plugin.css', :plugin => 'test_plugin' %>
<% end %>

<p>ContentForInsideHook content</p>
VIEW
  end

  class SingleRenderOn < Redmine::Hook::ViewListener
    render_on :view_welcome_index_left, :inline => 'SingleRenderOn 1'
  end

  class MultipleRenderOn < Redmine::Hook::ViewListener
    render_on :view_welcome_index_left, {:inline => 'MultipleRenderOn 1'}, {:inline => 'MultipleRenderOn 2'}
  end

  # Hooks that stores the call context
  class ContextTestHook < Redmine::Hook::ViewListener
    cattr_accessor :context

    def controller_account_success_authentication_after(context)
      self.class.context = context
    end
  end

  def setup
    Redmine::Hook.clear_listeners
  end

  def teardown
    Redmine::Hook.clear_listeners
  end

  def test_html_head_hook_response
    Redmine::Hook.add_listener(ProjectBasedTemplate)

    get '/projects/ecookbook'
    assert_select 'head link[href=?]', '/stylesheets/ecookbook.css'
  end

  def test_empty_sidebar_should_be_hidden
    get '/'
    assert_select 'div#main.nosidebar'
  end

  def test_sidebar_with_hook_content_should_not_be_hidden
    Redmine::Hook.add_listener(SidebarContent)

    get '/'
    assert_select 'div#sidebar p', :text => 'Sidebar hook'
    assert_select 'div#main'
    assert_select 'div#main.nosidebar', 0
  end

  def test_hook_with_content_for_should_append_content
    Redmine::Hook.add_listener(ContentForInsideHook)

    get '/'
    assert_response :success
    assert_select 'p', :text => 'ContentForInsideHook content'
    assert_select 'head' do
      assert_select 'script[src="/plugin_assets/test_plugin/javascripts/test_plugin.js"]'
      assert_select 'link[href="/plugin_assets/test_plugin/stylesheets/test_plugin.css"]'
    end
  end

  def test_controller_hook_context_should_include_request
    Redmine::Hook.add_listener(ContextTestHook)
    post '/login', :username => 'admin', :password => 'admin'
    assert_not_nil ContextTestHook.context
    context = ContextTestHook.context
    assert_kind_of ActionDispatch::Request, context[:request]
    assert_kind_of Hash, context[:request].params
    assert_kind_of AccountController, context[:hook_caller]
  end

  def test_multiple_hooks
    Redmine::Hook.add_listener(SingleRenderOn)
    Redmine::Hook.add_listener(MultipleRenderOn)
    get '/'
    assert_equal 1, response.body.scan("SingleRenderOn 1 MultipleRenderOn 1 MultipleRenderOn 2").size
  end
end
