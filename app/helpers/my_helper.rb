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

module MyHelper
  # Renders the blocks
  def render_blocks(blocks, user, options={})
    s = ''.html_safe

    if blocks.present?
      blocks.each do |block|
        s << render_block(block, user).to_s
      end
    end
    s
  end

  # Renders a single block
  def render_block(block, user)
    content = render_block_content(block, user)
    if content.present?
      handle = content_tag('span', '', :class => 'icon-only icon-sort-handle sort-handle', :title => l(:button_move))
      close = link_to(l(:button_delete),
                      {:action => "remove_block", :block => block},
                      :remote => true, :method => 'post',
                      :class => "icon-only icon-close", :title => l(:button_delete))
      content = content_tag('div', handle + close, :class => 'contextual') + content

      content_tag('div', content, :class => "mypage-box", :id => "block-#{block}")
    end
  end

  # Renders a single block content
  def render_block_content(block, user)
    unless block_definition = Redmine::MyPage.find_block(block)
      Rails.logger.warn("Unknown block \"#{block}\" found in #{user.login} (id=#{user.id}) preferences")
      return
    end

    settings = user.pref.my_page_settings(block)
    if partial = block_definition[:partial]
      begin
        render(:partial => partial, :locals => {:user => user, :settings => settings, :block => block})
      rescue ActionView::MissingTemplate
        Rails.logger.warn("Partial \"#{partial}\" missing for block \"#{block}\" found in #{user.login} (id=#{user.id}) preferences")
        return nil
      end
    else
      send "render_#{block_definition[:name]}_block", block, settings
    end
  end

  # Returns the select tag used to add a block to My page
  def block_select_tag(user)
    blocks_in_use = user.pref.my_page_layout.values.flatten
    options = content_tag('option')
    Redmine::MyPage.block_options(blocks_in_use).each do |label, block|
      options << content_tag('option', label, :value => block, :disabled => block.blank?)
    end
    select_tag('block', options, :id => "block-select", :onchange => "$('#block-form').submit();")
  end

  def render_calendar_block(block, settings)
    calendar = Redmine::Helpers::Calendar.new(User.current.today, current_language, :week)
    calendar.events = Issue.visible.
      where(:project => User.current.projects).
      where("(start_date>=? and start_date<=?) or (due_date>=? and due_date<=?)", calendar.startdt, calendar.enddt, calendar.startdt, calendar.enddt).
      includes(:project, :tracker, :priority, :assigned_to).
      references(:project, :tracker, :priority, :assigned_to).
      to_a

    render :partial => 'my/blocks/calendar', :locals => {:calendar => calendar, :block => block}
  end

  def render_documents_block(block, settings)
    documents = Document.visible.order("#{Document.table_name}.created_on DESC").limit(10).to_a

    render :partial => 'my/blocks/documents', :locals => {:block => block, :documents => documents}
  end

  def render_issuesassignedtome_block(block, settings)
    query = IssueQuery.new(:name => l(:label_assigned_to_me_issues), :user => User.current)
    query.add_filter 'assigned_to_id', '=', ['me']
    query.add_filter 'project.status', '=', ["#{Project::STATUS_ACTIVE}"]
    query.column_names = settings[:columns].presence || ['project', 'tracker', 'status', 'subject']
    query.sort_criteria = settings[:sort].presence || [['priority', 'desc'], ['updated_on', 'desc']]
    issues = query.issues(:limit => 10)

    render :partial => 'my/blocks/issues', :locals => {:query => query, :issues => issues, :block => block}
  end

  def render_issuesreportedbyme_block(block, settings)
    query = IssueQuery.new(:name => l(:label_reported_issues), :user => User.current)
    query.add_filter 'author_id', '=', ['me']
    query.add_filter 'project.status', '=', ["#{Project::STATUS_ACTIVE}"]
    query.column_names = settings[:columns].presence || ['project', 'tracker', 'status', 'subject']
    query.sort_criteria = settings[:sort].presence || [['updated_on', 'desc']]
    issues = query.issues(:limit => 10)

    render :partial => 'my/blocks/issues', :locals => {:query => query, :issues => issues, :block => block}
  end

  def render_issuesupdatedbyme_block(block, settings)
    query = IssueQuery.new(:name => l(:label_updated_issues), :user => User.current)
    query.add_filter 'updated_by', '=', ['me']
    query.add_filter 'project.status', '=', ["#{Project::STATUS_ACTIVE}"]
    query.column_names = settings[:columns].presence || ['project', 'tracker', 'status', 'subject']
    query.sort_criteria = settings[:sort].presence || [['updated_on', 'desc']]
    issues = query.issues(:limit => 10)

    render :partial => 'my/blocks/issues', :locals => {:query => query, :issues => issues, :block => block}
  end

  def render_issueswatched_block(block, settings)
    query = IssueQuery.new(:name => l(:label_watched_issues), :user => User.current)
    query.add_filter 'watcher_id', '=', ['me']
    query.add_filter 'project.status', '=', ["#{Project::STATUS_ACTIVE}"]
    query.column_names = settings[:columns].presence || ['project', 'tracker', 'status', 'subject']
    query.sort_criteria = settings[:sort].presence || [['updated_on', 'desc']]
    issues = query.issues(:limit => 10)

    render :partial => 'my/blocks/issues', :locals => {:query => query, :issues => issues, :block => block}
  end

  def render_issuequery_block(block, settings)
    query = IssueQuery.visible.find_by_id(settings[:query_id])

    if query
      query.column_names = settings[:columns] if settings[:columns].present?
      query.sort_criteria = settings[:sort] if settings[:sort].present?
      issues = query.issues(:limit => 10)
      render :partial => 'my/blocks/issues', :locals => {:query => query, :issues => issues, :block => block, :settings => settings}
    else
      queries = IssueQuery.visible.sorted
      render :partial => 'my/blocks/issue_query_selection', :locals => {:queries => queries, :block => block, :settings => settings}
    end
  end

  def render_news_block(block, settings)
    news = News.visible.
      where(:project => User.current.projects).
      limit(10).
      includes(:project, :author).
      references(:project, :author).
      order("#{News.table_name}.created_on DESC").
      to_a

    render :partial => 'my/blocks/news', :locals => {:block => block, :news => news}
  end

  def render_timelog_block(block, settings)
    days = settings[:days].to_i
    days = 7 if days < 1 || days > 365

    entries = TimeEntry.
      where("#{TimeEntry.table_name}.user_id = ? AND #{TimeEntry.table_name}.spent_on BETWEEN ? AND ?", User.current.id, User.current.today - (days - 1), User.current.today).
      joins(:activity, :project).
      references(:issue => [:tracker, :status]).
      includes(:issue => [:tracker, :status]).
      order("#{TimeEntry.table_name}.spent_on DESC, #{Project.table_name}.name ASC, #{Tracker.table_name}.position ASC, #{Issue.table_name}.id ASC").
      to_a
    entries_by_day = entries.group_by(&:spent_on)

    render :partial => 'my/blocks/timelog', :locals => {:block => block, :entries => entries, :entries_by_day => entries_by_day, :days => days}
  end

  def render_activity_block(block, settings)
    events_by_day = Redmine::Activity::Fetcher.new(User.current, :author => User.current).events(nil, nil, :limit => 10).group_by {|event| User.current.time_to_date(event.event_datetime)}

    render :partial => 'my/blocks/activity', :locals => {:events_by_day => events_by_day}
  end
end
