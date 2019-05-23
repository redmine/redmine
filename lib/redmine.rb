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

require 'redmine/core_ext'

begin
  require 'rmagick' unless Object.const_defined?(:Magick)
rescue LoadError
  # RMagick is not available
end
begin
  require 'redcarpet' unless Object.const_defined?(:Redcarpet)
rescue LoadError
  # Redcarpet is not available
end

require 'redmine/acts/positioned'

require 'redmine/scm/base'
require 'redmine/access_control'
require 'redmine/access_keys'
require 'redmine/activity'
require 'redmine/activity/fetcher'
require 'redmine/ciphering'
require 'redmine/codeset_util'
require 'redmine/field_format'
require 'redmine/info'
require 'redmine/menu_manager'
require 'redmine/notifiable'
require 'redmine/platform'
require 'redmine/mime_type'
require 'redmine/search'
require 'redmine/syntax_highlighting'
require 'redmine/thumbnail'
require 'redmine/unified_diff'
require 'redmine/utils'
require 'redmine/version'
require 'redmine/wiki_formatting'

require 'redmine/default_data/loader'
require 'redmine/helpers/calendar'
require 'redmine/helpers/diff'
require 'redmine/helpers/gantt'
require 'redmine/helpers/time_report'
require 'redmine/views/other_formats_builder'
require 'redmine/views/labelled_form_builder'
require 'redmine/views/builders'

require 'redmine/themes'
require 'redmine/hook'
require 'redmine/hook/listener'
require 'redmine/hook/view_listener'
require 'redmine/plugin'

Redmine::Scm::Base.add "Subversion"
Redmine::Scm::Base.add "Mercurial"
Redmine::Scm::Base.add "Cvs"
Redmine::Scm::Base.add "Bazaar"
Redmine::Scm::Base.add "Git"
Redmine::Scm::Base.add "Filesystem"

# Permissions
Redmine::AccessControl.map do |map|
  map.permission :view_project, {:projects => [:show], :activities => [:index]}, :public => true, :read => true
  map.permission :search_project, {:search => :index}, :public => true, :read => true
  map.permission :add_project, {:projects => [:new, :create]}, :require => :loggedin
  map.permission :edit_project, {:projects => [:settings, :edit, :update]}, :require => :member
  map.permission :close_project, {:projects => [:close, :reopen]}, :require => :member, :read => true
  map.permission :select_project_modules, {:projects => :modules}, :require => :member
  map.permission :view_members, {:members => [:index, :show]}, :public => true, :read => true
  map.permission :manage_members, {:projects => :settings, :members => [:index, :show, :new, :create, :edit, :update, :destroy, :autocomplete]}, :require => :member
  map.permission :manage_versions, {:projects => :settings, :versions => [:new, :create, :edit, :update, :close_completed, :destroy]}, :require => :member
  map.permission :add_subprojects, {:projects => [:new, :create]}, :require => :member
  # Queries
  map.permission :manage_public_queries, {:queries => [:new, :create, :edit, :update, :destroy]}, :require => :member
  map.permission :save_queries, {:queries => [:new, :create, :edit, :update, :destroy]}, :require => :loggedin

  map.project_module :issue_tracking do |map|
    # Issues
    map.permission :view_issues, {:issues => [:index, :show],
                                  :auto_complete => [:issues],
                                  :context_menus => [:issues],
                                  :versions => [:index, :show, :status_by],
                                  :journals => [:index, :diff],
                                  :queries => :index,
                                  :reports => [:issue_report, :issue_report_details]},
                                  :read => true
    map.permission :add_issues, {:issues => [:new, :create], :attachments => :upload}
    map.permission :edit_issues, {:issues => [:edit, :update, :bulk_edit, :bulk_update], :journals => [:new], :attachments => :upload}
    map.permission :copy_issues, {:issues => [:new, :create, :bulk_edit, :bulk_update], :attachments => :upload}
    map.permission :manage_issue_relations, {:issue_relations => [:index, :show, :create, :destroy]}
    map.permission :manage_subtasks, {}
    map.permission :set_issues_private, {}
    map.permission :set_own_issues_private, {}, :require => :loggedin
    map.permission :add_issue_notes, {:issues => [:edit, :update], :journals => [:new], :attachments => :upload}
    map.permission :edit_issue_notes, {:journals => [:edit, :update]}, :require => :loggedin
    map.permission :edit_own_issue_notes, {:journals => [:edit, :update]}, :require => :loggedin
    map.permission :view_private_notes, {}, :read => true, :require => :member
    map.permission :set_notes_private, {}, :require => :member
    map.permission :delete_issues, {:issues => :destroy}, :require => :member
    # Watchers
    map.permission :view_issue_watchers, {}, :read => true
    map.permission :add_issue_watchers, {:watchers => [:new, :create, :append, :autocomplete_for_user]}
    map.permission :delete_issue_watchers, {:watchers => :destroy}
    map.permission :import_issues, {:imports => [:new, :create, :settings, :mapping, :run, :show]}
    # Issue categories
    map.permission :manage_categories, {:projects => :settings, :issue_categories => [:index, :show, :new, :create, :edit, :update, :destroy]}, :require => :member
  end

  map.project_module :time_tracking do |map|
    map.permission :view_time_entries, {:timelog => [:index, :report, :show]}, :read => true
    map.permission :log_time, {:timelog => [:new, :create]}, :require => :loggedin
    map.permission :edit_time_entries, {:timelog => [:edit, :update, :destroy, :bulk_edit, :bulk_update]}, :require => :member
    map.permission :edit_own_time_entries, {:timelog => [:edit, :update, :destroy,:bulk_edit, :bulk_update]}, :require => :loggedin
    map.permission :manage_project_activities, {:projects => :settings, :project_enumerations => [:update, :destroy]}, :require => :member
  end

  map.project_module :news do |map|
    map.permission :view_news, {:news => [:index, :show]}, :read => true
    map.permission :manage_news, {:news => [:new, :create, :edit, :update, :destroy], :comments => [:destroy], :attachments => :upload}, :require => :member
    map.permission :comment_news, {:comments => :create}
  end

  map.project_module :documents do |map|
    map.permission :view_documents, {:documents => [:index, :show, :download]}, :read => true
    map.permission :add_documents, {:documents => [:new, :create, :add_attachment], :attachments => :upload}, :require => :loggedin
    map.permission :edit_documents, {:documents => [:edit, :update, :add_attachment], :attachments => :upload}, :require => :loggedin
    map.permission :delete_documents, {:documents => [:destroy]}, :require => :loggedin
  end

  map.project_module :files do |map|
    map.permission :view_files, {:files => :index, :versions => :download}, :read => true
    map.permission :manage_files, {:files => [:new, :create], :attachments => :upload}, :require => :loggedin
  end

  map.project_module :wiki do |map|
    map.permission :view_wiki_pages, {:wiki => [:index, :show, :special, :date_index]}, :read => true
    map.permission :view_wiki_edits, {:wiki => [:history, :diff, :annotate]}, :read => true
    map.permission :export_wiki_pages, {:wiki => [:export]}, :read => true
    map.permission :edit_wiki_pages, :wiki => [:new, :edit, :update, :preview, :add_attachment], :attachments => :upload
    map.permission :rename_wiki_pages, {:wiki => :rename}, :require => :member
    map.permission :delete_wiki_pages, {:wiki => [:destroy, :destroy_version]}, :require => :member
    map.permission :delete_wiki_pages_attachments, {}
    map.permission :protect_wiki_pages, {:wiki => :protect}, :require => :member
    map.permission :manage_wiki, {:wikis => [:edit, :destroy], :wiki => :rename}, :require => :member
  end

  map.project_module :repository do |map|
    map.permission :view_changesets, {:repositories => [:show, :revisions, :revision]}, :read => true
    map.permission :browse_repository, {:repositories => [:show, :browse, :entry, :raw, :annotate, :changes, :diff, :stats, :graph]}, :read => true
    map.permission :commit_access, {}
    map.permission :manage_related_issues, {:repositories => [:add_related_issue, :remove_related_issue]}
    map.permission :manage_repository, {:projects => :settings, :repositories => [:new, :create, :edit, :update, :committers, :destroy]}, :require => :member
  end

  map.project_module :boards do |map|
    map.permission :view_messages, {:boards => [:index, :show], :messages => [:show]}, :read => true
    map.permission :add_messages, {:messages => [:new, :reply, :quote], :attachments => :upload}
    map.permission :edit_messages, {:messages => :edit, :attachments => :upload}, :require => :member
    map.permission :edit_own_messages, {:messages => :edit, :attachments => :upload}, :require => :loggedin
    map.permission :delete_messages, {:messages => :destroy}, :require => :member
    map.permission :delete_own_messages, {:messages => :destroy}, :require => :loggedin
    map.permission :manage_boards, {:projects => :settings, :boards => [:new, :create, :edit, :update, :destroy]}, :require => :member
  end

  map.project_module :calendar do |map|
    map.permission :view_calendar, {:calendars => [:show, :update]}, :read => true
  end

  map.project_module :gantt do |map|
    map.permission :view_gantt, {:gantts => [:show, :update]}, :read => true
  end
end

Redmine::MenuManager.map :top_menu do |menu|
  menu.push :home, :home_path
  menu.push :my_page, { :controller => 'my', :action => 'page' }, :if => Proc.new { User.current.logged? }
  menu.push :projects, { :controller => 'projects', :action => 'index' }, :caption => :label_project_plural
  menu.push :administration, { :controller => 'admin', :action => 'index' }, :if => Proc.new { User.current.admin? }, :last => true
  menu.push :help, Redmine::Info.help_url, :last => true
end

Redmine::MenuManager.map :account_menu do |menu|
  menu.push :login, :signin_path, :if => Proc.new { !User.current.logged? }
  menu.push :register, :register_path, :if => Proc.new { !User.current.logged? && Setting.self_registration? }
  menu.push :my_account, { :controller => 'my', :action => 'account' }, :if => Proc.new { User.current.logged? }
  menu.push :logout, :signout_path, :html => {:method => 'post'}, :if => Proc.new { User.current.logged? }
end

Redmine::MenuManager.map :application_menu do |menu|
  menu.push :projects, {:controller => 'projects', :action => 'index'},
    :permission => nil,
    :caption => :label_project_plural
  menu.push :activity, {:controller => 'activities', :action => 'index'}
  menu.push :issues,   {:controller => 'issues', :action => 'index'},
    :if => Proc.new {User.current.allowed_to?(:view_issues, nil, :global => true)},
    :caption => :label_issue_plural
  menu.push :time_entries, {:controller => 'timelog', :action => 'index'},
    :if => Proc.new {User.current.allowed_to?(:view_time_entries, nil, :global => true)},
    :caption => :label_spent_time
  menu.push :gantt, { :controller => 'gantts', :action => 'show' }, :caption => :label_gantt,
    :if => Proc.new {User.current.allowed_to?(:view_gantt, nil, :global => true)}
  menu.push :calendar, { :controller => 'calendars', :action => 'show' }, :caption => :label_calendar,
    :if => Proc.new {User.current.allowed_to?(:view_calendar, nil, :global => true)}
  menu.push :news, {:controller => 'news', :action => 'index'},
    :if => Proc.new {User.current.allowed_to?(:view_news, nil, :global => true)},
    :caption => :label_news_plural
end

Redmine::MenuManager.map :admin_menu do |menu|
  menu.push :projects, {:controller => 'admin', :action => 'projects'}, :caption => :label_project_plural,
            :html => {:class => 'icon icon-projects'}
  menu.push :users, {:controller => 'users'}, :caption => :label_user_plural,
            :html => {:class => 'icon icon-user'}
  menu.push :groups, {:controller => 'groups'}, :caption => :label_group_plural,
            :html => {:class => 'icon icon-group'}
  menu.push :roles, {:controller => 'roles'}, :caption => :label_role_and_permissions,
            :html => {:class => 'icon icon-roles'}
  menu.push :trackers, {:controller => 'trackers'}, :caption => :label_tracker_plural,
            :html => {:class => 'icon icon-issue'}
  menu.push :issue_statuses, {:controller => 'issue_statuses'}, :caption => :label_issue_status_plural,
            :html => {:class => 'icon icon-issue-edit'}
  menu.push :workflows, {:controller => 'workflows', :action => 'edit'}, :caption => :label_workflow,
            :html => {:class => 'icon icon-workflows'}
  menu.push :custom_fields, {:controller => 'custom_fields'},  :caption => :label_custom_field_plural,
            :html => {:class => 'icon icon-custom-fields'}
  menu.push :enumerations, {:controller => 'enumerations'},
            :html => {:class => 'icon icon-list'}
  menu.push :settings, {:controller => 'settings'},
            :html => {:class => 'icon icon-settings'}
  menu.push :ldap_authentication, {:controller => 'auth_sources', :action => 'index'},
            :html => {:class => 'icon icon-server-authentication'}
  menu.push :plugins, {:controller => 'admin', :action => 'plugins'}, :last => true,
            :html => {:class => 'icon icon-plugins'}
  menu.push :info, {:controller => 'admin', :action => 'info'}, :caption => :label_information_plural, :last => true,
            :html => {:class => 'icon icon-help'}
end

Redmine::MenuManager.map :project_menu do |menu|
  menu.push :new_object, nil, :caption => ' + ',
              :if => Proc.new { |p| Setting.new_item_menu_tab == '2' },
              :html => { :id => 'new-object', :onclick => 'toggleNewObjectDropdown(); return false;' }
  menu.push :new_issue_sub, { :controller => 'issues', :action => 'new', :copy_from => nil }, :param => :project_id, :caption => :label_issue_new,
              :html => { :accesskey => Redmine::AccessKeys.key_for(:new_issue) },
              :if => Proc.new { |p| Issue.allowed_target_trackers(p).any? },
              :permission => :add_issues,
              :parent => :new_object
  menu.push :new_issue_category, {:controller => 'issue_categories', :action => 'new'}, :param => :project_id, :caption => :label_issue_category_new,
              :parent => :new_object
  menu.push :new_version, {:controller => 'versions', :action => 'new'}, :param => :project_id, :caption => :label_version_new,
              :parent => :new_object
  menu.push :new_timelog, {:controller => 'timelog', :action => 'new'}, :param => :project_id, :caption => :button_log_time,
              :parent => :new_object
  menu.push :new_news, {:controller => 'news', :action => 'new'}, :param => :project_id, :caption => :label_news_new,
              :parent => :new_object
  menu.push :new_document, {:controller => 'documents', :action => 'new'}, :param => :project_id, :caption => :label_document_new,
              :parent => :new_object
  menu.push :new_wiki_page, {:controller => 'wiki', :action => 'new'}, :param => :project_id, :caption => :label_wiki_page_new,
              :parent => :new_object
  menu.push :new_file, {:controller => 'files', :action => 'new'}, :param => :project_id, :caption => :label_attachment_new,
              :parent => :new_object

  menu.push :overview, { :controller => 'projects', :action => 'show' }
  menu.push :activity, { :controller => 'activities', :action => 'index' }
  menu.push :roadmap, { :controller => 'versions', :action => 'index' }, :param => :project_id,
              :if => Proc.new { |p| p.shared_versions.any? }
  menu.push :issues, { :controller => 'issues', :action => 'index' }, :param => :project_id, :caption => :label_issue_plural
  menu.push :new_issue, { :controller => 'issues', :action => 'new', :copy_from => nil }, :param => :project_id, :caption => :label_issue_new,
              :html => { :accesskey => Redmine::AccessKeys.key_for(:new_issue) },
              :if => Proc.new { |p| Setting.new_item_menu_tab == '1' && Issue.allowed_target_trackers(p).any? },
              :permission => :add_issues
  menu.push :time_entries, { :controller => 'timelog', :action => 'index' }, :param => :project_id, :caption => :label_spent_time
  menu.push :gantt, { :controller => 'gantts', :action => 'show' }, :param => :project_id, :caption => :label_gantt
  menu.push :calendar, { :controller => 'calendars', :action => 'show' }, :param => :project_id, :caption => :label_calendar
  menu.push :news, { :controller => 'news', :action => 'index' }, :param => :project_id, :caption => :label_news_plural
  menu.push :documents, { :controller => 'documents', :action => 'index' }, :param => :project_id, :caption => :label_document_plural
  menu.push :wiki, { :controller => 'wiki', :action => 'show', :id => nil }, :param => :project_id,
              :if => Proc.new { |p| p.wiki && !p.wiki.new_record? }
  menu.push :boards, { :controller => 'boards', :action => 'index', :id => nil }, :param => :project_id,
              :if => Proc.new { |p| p.boards.any? }, :caption => :label_board_plural
  menu.push :files, { :controller => 'files', :action => 'index' }, :caption => :label_file_plural, :param => :project_id
  menu.push :repository, { :controller => 'repositories', :action => 'show', :repository_id => nil, :path => nil, :rev => nil },
              :if => Proc.new { |p| p.repository && !p.repository.new_record? }
  menu.push :settings, { :controller => 'projects', :action => 'settings' }, :last => true
end

Redmine::Activity.map do |activity|
  activity.register :issues, :class_name => %w(Issue Journal)
  activity.register :changesets
  activity.register :news
  activity.register :documents, :class_name => %w(Document Attachment)
  activity.register :files, :class_name => 'Attachment'
  activity.register :wiki_edits, :class_name => 'WikiContent::Version', :default => false
  activity.register :messages, :default => false
  activity.register :time_entries, :default => false
end

Redmine::Search.map do |search|
  search.register :issues
  search.register :news
  search.register :documents
  search.register :changesets
  search.register :wiki_pages
  search.register :messages
  search.register :projects
end

Redmine::WikiFormatting.map do |format|
  format.register :textile
  format.register :markdown if Object.const_defined?(:Redcarpet)
end

ActionView::Template.register_template_handler :rsb, Redmine::Views::ApiTemplateHandler
