# encoding: utf-8
#
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

require 'forwardable'
require 'cgi'

module ApplicationHelper
  include Redmine::WikiFormatting::Macros::Definitions
  include Redmine::I18n
  include GravatarHelper::PublicMethods
  include Redmine::Pagination::Helper
  include Redmine::SudoMode::Helper
  include Redmine::Themes::Helper
  include Redmine::Hook::Helper
  include Redmine::Helpers::URL

  extend Forwardable
  def_delegators :wiki_helper, :wikitoolbar_for, :heads_for_wiki_formatter

  # Return true if user is authorized for controller/action, otherwise false
  def authorize_for(controller, action)
    User.current.allowed_to?({:controller => controller, :action => action}, @project)
  end

  # Display a link if user is authorized
  #
  # @param [String] name Anchor text (passed to link_to)
  # @param [Hash] options Hash params. This will checked by authorize_for to see if the user is authorized
  # @param [optional, Hash] html_options Options passed to link_to
  # @param [optional, Hash] parameters_for_method_reference Extra parameters for link_to
  def link_to_if_authorized(name, options = {}, html_options = nil, *parameters_for_method_reference)
    link_to(name, options, html_options, *parameters_for_method_reference) if authorize_for(options[:controller] || params[:controller], options[:action])
  end

  # Displays a link to user's account page if active
  def link_to_user(user, options={})
    if user.is_a?(User)
      name = h(user.name(options[:format]))
      if user.active? || (User.current.admin? && user.logged?)
        only_path = options[:only_path].nil? ? true : options[:only_path]
        link_to name, user_url(user, :only_path => only_path), :class => user.css_classes
      else
        name
      end
    else
      h(user.to_s)
    end
  end

  # Displays a link to +issue+ with its subject.
  # Examples:
  #
  #   link_to_issue(issue)                        # => Defect #6: This is the subject
  #   link_to_issue(issue, :truncate => 6)        # => Defect #6: This i...
  #   link_to_issue(issue, :subject => false)     # => Defect #6
  #   link_to_issue(issue, :project => true)      # => Foo - Defect #6
  #   link_to_issue(issue, :subject => false, :tracker => false)     # => #6
  #
  def link_to_issue(issue, options={})
    title = nil
    subject = nil
    text = options[:tracker] == false ? "##{issue.id}" : "#{issue.tracker} ##{issue.id}"
    if options[:subject] == false
      title = issue.subject.truncate(60)
    else
      subject = issue.subject
      if truncate_length = options[:truncate]
        subject = subject.truncate(truncate_length)
      end
    end
    only_path = options[:only_path].nil? ? true : options[:only_path]
    s = link_to(text, issue_url(issue, :only_path => only_path),
                :class => issue.css_classes, :title => title)
    s << h(": #{subject}") if subject
    s = h("#{issue.project} - ") + s if options[:project]
    s
  end

  # Generates a link to an attachment.
  # Options:
  # * :text - Link text (default to attachment filename)
  # * :download - Force download (default: false)
  def link_to_attachment(attachment, options={})
    text = options.delete(:text) || attachment.filename
    if options.delete(:download)
      route_method = :download_named_attachment_url
      options[:filename] = attachment.filename
    else
      route_method = :attachment_url
      # make sure we don't have an extraneous :filename in the options
      options.delete(:filename)
    end
    html_options = options.slice!(:only_path, :filename)
    options[:only_path] = true unless options.key?(:only_path)
    url = send(route_method, attachment, options)
    link_to text, url, html_options
  end

  # Generates a link to a SCM revision
  # Options:
  # * :text - Link text (default to the formatted revision)
  def link_to_revision(revision, repository, options={})
    if repository.is_a?(Project)
      repository = repository.repository
    end
    text = options.delete(:text) || format_revision(revision)
    rev = revision.respond_to?(:identifier) ? revision.identifier : revision
    link_to(
        h(text),
        {:controller => 'repositories', :action => 'revision', :id => repository.project, :repository_id => repository.identifier_param, :rev => rev},
        :title => l(:label_revision_id, format_revision(revision)),
        :accesskey => options[:accesskey]
      )
  end

  # Generates a link to a message
  def link_to_message(message, options={}, html_options = nil)
    link_to(
      message.subject.truncate(60),
      board_message_url(message.board_id, message.parent_id || message.id, {
        :r => (message.parent_id && message.id),
        :anchor => (message.parent_id ? "message-#{message.id}" : nil),
        :only_path => true
      }.merge(options)),
      html_options
    )
  end

  # Generates a link to a project if active
  # Examples:
  #
  #   link_to_project(project)                          # => link to the specified project overview
  #   link_to_project(project, {:only_path => false}, :class => "project") # => 3rd arg adds html options
  #   link_to_project(project, {}, :class => "project") # => html options with default url (project overview)
  #
  def link_to_project(project, options={}, html_options = nil)
    if project.archived?
      h(project.name)
    else
      link_to project.name,
        project_url(project, {:only_path => true}.merge(options)),
        html_options
    end
  end

  # Generates a link to a project settings if active
  def link_to_project_settings(project, options={}, html_options=nil)
    if project.active?
      link_to project.name, settings_project_path(project, options), html_options
    elsif project.archived?
      h(project.name)
    else
      link_to project.name, project_path(project, options), html_options
    end
  end

  # Generates a link to a version
  def link_to_version(version, options = {})
    return '' unless version && version.is_a?(Version)
    options = {:title => format_date(version.effective_date)}.merge(options)
    link_to_if version.visible?, format_version_name(version), version_path(version), options
  end

  RECORD_LINK = {
    'CustomValue'  => -> (custom_value) { link_to_record(custom_value.customized) },
    'Document'     => -> (document)     { link_to(document.title, document_path(document)) },
    'Group'        => -> (group)        { link_to(group.name, group_path(group)) },
    'Issue'        => -> (issue)        { link_to_issue(issue, :subject => false) },
    'Message'      => -> (message)      { link_to_message(message) },
    'News'         => -> (news)         { link_to(news.title, news_path(news)) },
    'Project'      => -> (project)      { link_to_project(project) },
    'User'         => -> (user)         { link_to_user(user) },
    'Version'      => -> (version)      { link_to_version(version) },
    'WikiPage'     => -> (wiki_page)    { link_to(wiki_page.pretty_title, project_wiki_page_path(wiki_page.project, wiki_page.title)) }
  }

  def link_to_record(record)
    if link = RECORD_LINK[record.class.name]
      self.instance_exec(record, &link)
    end
  end

  ATTACHMENT_CONTAINER_LINK = {
    # Custom list, since project/version attachments are listed in the files
    # view and not in the project/milestone view
    'Project'      => -> (project)      { link_to(l(:project_module_files), project_files_path(project)) },
    'Version'      => -> (version)      { link_to(l(:project_module_files), project_files_path(version.project)) },
  }

  def link_to_attachment_container(attachment_container)
    if link = ATTACHMENT_CONTAINER_LINK[attachment_container.class.name] ||
              RECORD_LINK[attachment_container.class.name]
      self.instance_exec(attachment_container, &link)
    end
  end


  # Helper that formats object for html or text rendering
  def format_object(object, html=true, &block)
    if block_given?
      object = yield object
    end
    case object.class.name
    when 'Array'
      formatted_objects = object.map {|o| format_object(o, html)}
      html ? safe_join(formatted_objects, ', ') : formatted_objects.join(', ')
    when 'Time'
      format_time(object)
    when 'Date'
      format_date(object)
    when 'Fixnum'
      object.to_s
    when 'Float'
      sprintf "%.2f", object
    when 'User'
      html ? link_to_user(object) : object.to_s
    when 'Project'
      html ? link_to_project(object) : object.to_s
    when 'Version'
      html ? link_to_version(object) : object.to_s
    when 'TrueClass'
      l(:general_text_Yes)
    when 'FalseClass'
      l(:general_text_No)
    when 'Issue'
      object.visible? && html ? link_to_issue(object) : "##{object.id}"
    when 'Attachment'
      html ? link_to_attachment(object) : object.filename
    when 'CustomValue', 'CustomFieldValue'
      if object.custom_field
        f = object.custom_field.format.formatted_custom_value(self, object, html)
        if f.nil? || f.is_a?(String)
          f
        else
          format_object(f, html, &block)
        end
      else
        object.value.to_s
      end
    else
      html ? h(object) : object.to_s
    end
  end

  def wiki_page_path(page, options={})
    url_for({:controller => 'wiki', :action => 'show', :project_id => page.project, :id => page.title}.merge(options))
  end

  def thumbnail_tag(attachment)
    thumbnail_size = Setting.thumbnails_size.to_i
    link_to(
      image_tag(
        thumbnail_path(attachment),
        :srcset => "#{thumbnail_path(attachment, :size => thumbnail_size * 2)} 2x",
        :style => "max-width: #{thumbnail_size}px; max-height: #{thumbnail_size}px;"
      ),
      attachment_path(
        attachment
      ),
      :title => attachment.filename
    )
  end

  def toggle_link(name, id, options={})
    onclick = "$('##{id}').toggle(); "
    onclick << (options[:focus] ? "$('##{options[:focus]}').focus(); " : "this.blur(); ")
    onclick << "$(window).scrollTop($('##{options[:focus]}').position().top); " if options[:scroll]
    onclick << "return false;"
    link_to(name, "#", :onclick => onclick)
  end

  # Used to format item titles on the activity view
  def format_activity_title(text)
    text
  end

  def format_activity_day(date)
    date == User.current.today ? l(:label_today).titleize : format_date(date)
  end

  def format_activity_description(text)
    h(text.to_s.truncate(120).gsub(%r{[\r\n]*<(pre|code)>.*$}m, '...')
       ).gsub(/[\r\n]+/, "<br />").html_safe
  end

  def format_version_name(version)
    if version.project == @project
      h(version)
    else
      h("#{version.project} - #{version}")
    end
  end

  def format_changeset_comments(changeset, options={})
    method = options[:short] ? :short_comments : :comments
    textilizable changeset, method, :formatting => Setting.commit_logs_formatting?
  end

  def due_date_distance_in_words(date)
    if date
      l((date < User.current.today ? :label_roadmap_overdue : :label_roadmap_due_in), distance_of_date_in_words(User.current.today, date))
    end
  end

  # Renders a tree of projects as a nested set of unordered lists
  # The given collection may be a subset of the whole project tree
  # (eg. some intermediate nodes are private and can not be seen)
  def render_project_nested_lists(projects, &block)
    s = ''
    if projects.any?
      ancestors = []
      original_project = @project
      projects.sort_by(&:lft).each do |project|
        # set the project environment to please macros.
        @project = project
        if (ancestors.empty? || project.is_descendant_of?(ancestors.last))
          s << "<ul class='projects #{ ancestors.empty? ? 'root' : nil}'>\n"
        else
          ancestors.pop
          s << "</li>"
          while (ancestors.any? && !project.is_descendant_of?(ancestors.last))
            ancestors.pop
            s << "</ul></li>\n"
          end
        end
        classes = (ancestors.empty? ? 'root' : 'child')
        s << "<li class='#{classes}'><div class='#{classes}'>"
        s << h(block_given? ? capture(project, &block) : project.name)
        s << "</div>\n"
        ancestors << project
      end
      s << ("</li></ul>\n" * ancestors.size)
      @project = original_project
    end
    s.html_safe
  end

  def render_page_hierarchy(pages, node=nil, options={})
    content = ''
    if pages[node]
      content << "<ul class=\"pages-hierarchy\">\n"
      pages[node].each do |page|
        content << "<li>"
        content << link_to(h(page.pretty_title), {:controller => 'wiki', :action => 'show', :project_id => page.project, :id => page.title, :version => nil},
                           :title => (options[:timestamp] && page.updated_on ? l(:label_updated_time, distance_of_time_in_words(Time.now, page.updated_on)) : nil))
        content << "\n" + render_page_hierarchy(pages, page.id, options) if pages[page.id]
        content << "</li>\n"
      end
      content << "</ul>\n"
    end
    content.html_safe
  end

  # Renders flash messages
  def render_flash_messages
    s = ''
    flash.each do |k,v|
      s << content_tag('div', v.html_safe, :class => "flash #{k}", :id => "flash_#{k}")
    end
    s.html_safe
  end

  # Renders tabs and their content
  def render_tabs(tabs, selected=params[:tab])
    if tabs.any?
      unless tabs.detect {|tab| tab[:name] == selected}
        selected = nil
      end
      selected ||= tabs.first[:name]
      render :partial => 'common/tabs', :locals => {:tabs => tabs, :selected_tab => selected}
    else
      content_tag 'p', l(:label_no_data), :class => "nodata"
    end
  end

  # Returns the default scope for the quick search form
  # Could be 'all', 'my_projects', 'subprojects' or nil (current project)
  def default_search_project_scope
    if @project && !@project.leaf?
      'subprojects'
    end
  end

  # Returns an array of projects that are displayed in the quick-jump box
  def projects_for_jump_box(user=User.current)
    if user.logged?
      user.projects.active.select(:id, :name, :identifier, :lft, :rgt).to_a
    else
      []
    end
  end

  def render_projects_for_jump_box(projects, selected=nil)
    jump = params[:jump].presence || current_menu_item
    s = ''.html_safe
    project_tree(projects) do |project, level|
      padding = level * 16
      text = content_tag('span', project.name, :style => "padding-left:#{padding}px;")
      s << link_to(text, project_path(project, :jump => jump), :title => project.name, :class => (project == selected ? 'selected' : nil))
    end
    s
  end

  # Renders the project quick-jump box
  def render_project_jump_box
    projects = projects_for_jump_box(User.current)
    if @project && @project.persisted?
      text = @project.name_was
    end
    text ||= l(:label_jump_to_a_project)
    url = autocomplete_projects_path(:format => 'js', :jump => current_menu_item)

    trigger = content_tag('span', text, :class => 'drdn-trigger')
    q = text_field_tag('q', '', :id => 'projects-quick-search', :class => 'autocomplete', :data => {:automcomplete_url => url}, :autocomplete => 'off')
    all = link_to(l(:label_project_all), projects_path(:jump => current_menu_item), :class => (@project.nil? && controller.class.main_menu ? 'selected' : nil))
    content = content_tag('div',
          content_tag('div', q, :class => 'quick-search') +
          content_tag('div', render_projects_for_jump_box(projects, @project), :class => 'drdn-items projects selection') +
          content_tag('div', all, :class => 'drdn-items all-projects selection'),
        :class => 'drdn-content'
      )

    content_tag('div', trigger + content, :id => "project-jump", :class => "drdn")
  end

  def project_tree_options_for_select(projects, options = {})
    s = ''.html_safe
    if blank_text = options[:include_blank]
      if blank_text == true
        blank_text = '&nbsp;'.html_safe
      end
      s << content_tag('option', blank_text, :value => '')
    end
    project_tree(projects) do |project, level|
      name_prefix = (level > 0 ? '&nbsp;' * 2 * level + '&#187; ' : '').html_safe
      tag_options = {:value => project.id}
      if project == options[:selected] || (options[:selected].respond_to?(:include?) && options[:selected].include?(project))
        tag_options[:selected] = 'selected'
      else
        tag_options[:selected] = nil
      end
      tag_options.merge!(yield(project)) if block_given?
      s << content_tag('option', name_prefix + h(project), tag_options)
    end
    s.html_safe
  end

  # Yields the given block for each project with its level in the tree
  #
  # Wrapper for Project#project_tree
  def project_tree(projects, options={}, &block)
    Project.project_tree(projects, options, &block)
  end

  def principals_check_box_tags(name, principals)
    s = ''
    principals.each do |principal|
      s << "<label>#{ check_box_tag name, principal.id, false, :id => nil } #{h principal}</label>\n"
    end
    s.html_safe
  end

  # Returns a string for users/groups option tags
  def principals_options_for_select(collection, selected=nil)
    s = ''
    if collection.include?(User.current)
      s << content_tag('option', "<< #{l(:label_me)} >>", :value => User.current.id)
    end
    groups = ''
    collection.sort.each do |element|
      selected_attribute = ' selected="selected"' if option_value_selected?(element, selected) || element.id.to_s == selected
      (element.is_a?(Group) ? groups : s) << %(<option value="#{element.id}"#{selected_attribute}>#{h element.name}</option>)
    end
    unless groups.empty?
      s << %(<optgroup label="#{h(l(:label_group_plural))}">#{groups}</optgroup>)
    end
    s.html_safe
  end

  def option_tag(name, text, value, selected=nil, options={})
    content_tag 'option', value, options.merge(:value => value, :selected => (value == selected))
  end

  def truncate_single_line_raw(string, length)
    string.to_s.truncate(length).gsub(%r{[\r\n]+}m, ' ')
  end

  # Truncates at line break after 250 characters or options[:length]
  def truncate_lines(string, options={})
    length = options[:length] || 250
    if string.to_s =~ /\A(.{#{length}}.*?)$/m
      "#{$1}..."
    else
      string
    end
  end

  def anchor(text)
    text.to_s.tr(' ', '_')
  end

  def html_hours(text)
    text.gsub(%r{(\d+)([\.:])(\d+)}, '<span class="hours hours-int">\1</span><span class="hours hours-dec">\2\3</span>').html_safe
  end

  def authoring(created, author, options={})
    l(options[:label] || :label_added_time_by, :author => link_to_user(author), :age => time_tag(created)).html_safe
  end

  def time_tag(time)
    text = distance_of_time_in_words(Time.now, time)
    if @project
      link_to(text, project_activity_path(@project, :from => User.current.time_to_date(time)), :title => format_time(time))
    else
      content_tag('abbr', text, :title => format_time(time))
    end
  end

  def syntax_highlight_lines(name, content)
    syntax_highlight(name, content).each_line.to_a
  end

  def syntax_highlight(name, content)
    Redmine::SyntaxHighlighting.highlight_by_filename(content, name)
  end

  def to_path_param(path)
    str = path.to_s.split(%r{[/\\]}).select{|p| !p.blank?}.join("/")
    str.blank? ? nil : str
  end

  def reorder_handle(object, options={})
    data = {
      :reorder_url => options[:url] || url_for(object),
      :reorder_param => options[:param] || object.class.name.underscore
    }
    content_tag('span', '',
      :class => "sort-handle",
      :data => data,
      :title => l(:button_sort))
  end

  def breadcrumb(*args)
    elements = args.flatten
    elements.any? ? content_tag('p', (args.join(" \xc2\xbb ") + " \xc2\xbb ").html_safe, :class => 'breadcrumb') : nil
  end

  def other_formats_links(&block)
    concat('<p class="other-formats">'.html_safe + l(:label_export_to))
    yield Redmine::Views::OtherFormatsBuilder.new(self)
    concat('</p>'.html_safe)
  end

  def page_header_title
    if @project.nil? || @project.new_record?
      h(Setting.app_title)
    else
      b = []
      ancestors = (@project.root? ? [] : @project.ancestors.visible.to_a)
      if ancestors.any?
        root = ancestors.shift
        b << link_to_project(root, {:jump => current_menu_item}, :class => 'root')
        if ancestors.size > 2
          b << "\xe2\x80\xa6"
          ancestors = ancestors[-2, 2]
        end
        b += ancestors.collect {|p| link_to_project(p, {:jump => current_menu_item}, :class => 'ancestor') }
      end
      b << content_tag(:span, h(@project), class: 'current-project')
      if b.size > 1
        separator = content_tag(:span, ' &raquo; '.html_safe, class: 'separator')
        path = safe_join(b[0..-2], separator) + separator
        b = [content_tag(:span, path.html_safe, class: 'breadcrumbs'), b[-1]]
      end
      safe_join b
    end
  end

  # Returns a h2 tag and sets the html title with the given arguments
  def title(*args)
    strings = args.map do |arg|
      if arg.is_a?(Array) && arg.size >= 2
        link_to(*arg)
      else
        h(arg.to_s)
      end
    end
    html_title args.reverse.map {|s| (s.is_a?(Array) ? s.first : s).to_s}
    content_tag('h2', strings.join(' &#187; ').html_safe)
  end

  # Sets the html title
  # Returns the html title when called without arguments
  # Current project name and app_title and automatically appended
  # Exemples:
  #   html_title 'Foo', 'Bar'
  #   html_title # => 'Foo - Bar - My Project - Redmine'
  def html_title(*args)
    if args.empty?
      title = @html_title || []
      title << @project.name if @project
      title << Setting.app_title unless Setting.app_title == title.last
      title.reject(&:blank?).join(' - ')
    else
      @html_title ||= []
      @html_title += args
    end
  end

  def actions_dropdown(&block)
    content = capture(&block)
    if content.present?
      trigger = content_tag('span', l(:button_actions), :class => 'icon-only icon-actions', :title => l(:button_actions))
      trigger = content_tag('span', trigger, :class => 'drdn-trigger')
      content = content_tag('div', content, :class => 'drdn-items')
      content = content_tag('div', content, :class => 'drdn-content')
      content_tag('span', trigger + content, :class => 'drdn')
    end
  end

  # Returns the theme, controller name, and action as css classes for the
  # HTML body.
  def body_css_classes
    css = []
    if theme = Redmine::Themes.theme(Setting.ui_theme)
      css << 'theme-' + theme.name
    end

    css << 'project-' + @project.identifier if @project && @project.identifier.present?
    css << 'has-main-menu' if display_main_menu?(@project)
    css << 'controller-' + controller_name
    css << 'action-' + action_name
    css << 'avatars-' + (Setting.gravatar_enabled? ? 'on' : 'off')
    if UserPreference::TEXTAREA_FONT_OPTIONS.include?(User.current.pref.textarea_font)
      css << "textarea-#{User.current.pref.textarea_font}"
    end
    css.join(' ')
  end

  def accesskey(s)
    @used_accesskeys ||= []
    key = Redmine::AccessKeys.key_for(s)
    return nil if @used_accesskeys.include?(key)
    @used_accesskeys << key
    key
  end

  # Formats text according to system settings.
  # 2 ways to call this method:
  # * with a String: textilizable(text, options)
  # * with an object and one of its attribute: textilizable(issue, :description, options)
  def textilizable(*args)
    options = args.last.is_a?(Hash) ? args.pop : {}
    case args.size
    when 1
      obj = options[:object]
      text = args.shift
    when 2
      obj = args.shift
      attr = args.shift
      text = obj.send(attr).to_s
    else
      raise ArgumentError, 'invalid arguments to textilizable'
    end
    return '' if text.blank?
    project = options[:project] || @project || (obj && obj.respond_to?(:project) ? obj.project : nil)
    @only_path = only_path = options.delete(:only_path) == false ? false : true

    text = text.dup
    macros = catch_macros(text)

    if options[:formatting] == false
      text = h(text)
    else
      formatting = Setting.text_formatting
      text = Redmine::WikiFormatting.to_html(formatting, text, :object => obj, :attribute => attr)
    end

    @parsed_headings = []
    @heading_anchors = {}
    @current_section = 0 if options[:edit_section_links]

    parse_sections(text, project, obj, attr, only_path, options)
    text = parse_non_pre_blocks(text, obj, macros) do |text|
      [:parse_inline_attachments, :parse_hires_images, :parse_wiki_links, :parse_redmine_links].each do |method_name|
        send method_name, text, project, obj, attr, only_path, options
      end
    end
    parse_headings(text, project, obj, attr, only_path, options)

    if @parsed_headings.any?
      replace_toc(text, @parsed_headings)
    end

    text.html_safe
  end

  def parse_non_pre_blocks(text, obj, macros)
    s = StringScanner.new(text)
    tags = []
    parsed = ''
    while !s.eos?
      s.scan(/(.*?)(<(\/)?(pre|code)(.*?)>|\z)/im)
      text, full_tag, closing, tag = s[1], s[2], s[3], s[4]
      if tags.empty?
        yield text
        inject_macros(text, obj, macros) if macros.any?
      else
        inject_macros(text, obj, macros, false) if macros.any?
      end
      parsed << text
      if tag
        if closing
          if tags.last && tags.last.casecmp(tag) == 0
            tags.pop
          end
        else
          tags << tag.downcase
        end
        parsed << full_tag
      end
    end
    # Close any non closing tags
    while tag = tags.pop
      parsed << "</#{tag}>"
    end
    parsed
  end

  # add srcset attribute to img tags if filename includes @2x, @3x, etc.
  # to support hires displays
  def parse_hires_images(text, project, obj, attr, only_path, options)
    text.gsub!(/src="([^"]+@(\dx)\.(bmp|gif|jpg|jpe|jpeg|png))"/i) do |m|
      filename, dpr = $1, $2
      m + " srcset=\"#{filename} #{dpr}\""
    end
  end

  def parse_inline_attachments(text, project, obj, attr, only_path, options)
    return if options[:inline_attachments] == false

    # when using an image link, try to use an attachment, if possible
    attachments = options[:attachments] || []
    attachments += obj.attachments if obj.respond_to?(:attachments)
    if attachments.present?
      text.gsub!(/src="([^\/"]+\.(bmp|gif|jpg|jpe|jpeg|png))"(\s+alt="([^"]*)")?/i) do |m|
        filename, ext, alt, alttext = $1, $2, $3, $4
        # search for the picture in attachments
        if found = Attachment.latest_attach(attachments, CGI.unescape(filename))
          image_url = download_named_attachment_url(found, found.filename, :only_path => only_path)
          desc = found.description.to_s.gsub('"', '')
          if !desc.blank? && alttext.blank?
            alt = " title=\"#{desc}\" alt=\"#{desc}\""
          end
          "src=\"#{image_url}\"#{alt}"
        else
          m
        end
      end
    end
  end

  # Wiki links
  #
  # Examples:
  #   [[mypage]]
  #   [[mypage|mytext]]
  # wiki links can refer other project wikis, using project name or identifier:
  #   [[project:]] -> wiki starting page
  #   [[project:|mytext]]
  #   [[project:mypage]]
  #   [[project:mypage|mytext]]
  def parse_wiki_links(text, project, obj, attr, only_path, options)
    text.gsub!(/(!)?(\[\[([^\n\|]+?)(\|([^\n\|]+?))?\]\])/) do |m|
      link_project = project
      esc, all, page, title = $1, $2, $3, $5
      if esc.nil?
        page = CGI.unescapeHTML(page)
        if page =~ /^\#(.+)$/
          anchor = sanitize_anchor_name($1)
          url = "##{anchor}"
          next link_to(title.present? ? title.html_safe : h(page), url, :class => 'wiki-page')
        end

        if page =~ /^([^\:]+)\:(.*)$/
          identifier, page = $1, $2
          link_project = Project.find_by_identifier(identifier) || Project.find_by_name(identifier)
          title ||= identifier if page.blank?
        end

        if link_project && link_project.wiki && User.current.allowed_to?(:view_wiki_pages, link_project)
          # extract anchor
          anchor = nil
          if page =~ /^(.+?)\#(.+)$/
            page, anchor = $1, $2
          end
          anchor = sanitize_anchor_name(anchor) if anchor.present?
          # check if page exists
          wiki_page = link_project.wiki.find_page(page)
          url = if anchor.present? && wiki_page.present? && (obj.is_a?(WikiContent) || obj.is_a?(WikiContent::Version)) && obj.page == wiki_page
            "##{anchor}"
          else
            case options[:wiki_links]
            when :local; "#{page.present? ? Wiki.titleize(page) : ''}.html" + (anchor.present? ? "##{anchor}" : '')
            when :anchor; "##{page.present? ? Wiki.titleize(page) : title}" + (anchor.present? ? "_#{anchor}" : '') # used for single-file wiki export
            else
              wiki_page_id = page.present? ? Wiki.titleize(page) : nil
              parent = wiki_page.nil? && obj.is_a?(WikiContent) && obj.page && project == link_project ? obj.page.title : nil
              url_for(:only_path => only_path, :controller => 'wiki', :action => 'show', :project_id => link_project,
               :id => wiki_page_id, :version => nil, :anchor => anchor, :parent => parent)
            end
          end
          link_to(title.present? ? title.html_safe : h(page), url, :class => ('wiki-page' + (wiki_page ? '' : ' new')))
        else
          # project or wiki doesn't exist
          all
        end
      else
        all
      end
    end
  end

  # Redmine links
  #
  # Examples:
  #   Issues:
  #     #52 -> Link to issue #52
  #     ##52 -> Link to issue #52, including the issue's subject
  #   Changesets:
  #     r52 -> Link to revision 52
  #     commit:a85130f -> Link to scmid starting with a85130f
  #   Documents:
  #     document#17 -> Link to document with id 17
  #     document:Greetings -> Link to the document with title "Greetings"
  #     document:"Some document" -> Link to the document with title "Some document"
  #   Versions:
  #     version#3 -> Link to version with id 3
  #     version:1.0.0 -> Link to version named "1.0.0"
  #     version:"1.0 beta 2" -> Link to version named "1.0 beta 2"
  #   Attachments:
  #     attachment:file.zip -> Link to the attachment of the current object named file.zip
  #   Source files:
  #     source:some/file -> Link to the file located at /some/file in the project's repository
  #     source:some/file@52 -> Link to the file's revision 52
  #     source:some/file#L120 -> Link to line 120 of the file
  #     source:some/file@52#L120 -> Link to line 120 of the file's revision 52
  #     export:some/file -> Force the download of the file
  #   Forums:
  #     forum#1 -> Link to forum with id 1
  #     forum:Support -> Link to forum named "Support"
  #     forum:"Technical Support" -> Link to forum named "Technical Support"
  #   Forum messages:
  #     message#1218 -> Link to message with id 1218
  #   Projects:
  #     project:someproject -> Link to project named "someproject"
  #     project#3 -> Link to project with id 3
  #   News:
  #     news#2 -> Link to news item with id 1
  #     news:Greetings -> Link to news item named "Greetings"
  #     news:"First Release" -> Link to news item named "First Release"
  #   Users:
  #     user:jsmith -> Link to user with login jsmith
  #     @jsmith -> Link to user with login jsmith
  #     user#2 -> Link to user with id 2
  #
  #   Links can refer other objects from other projects, using project identifier:
  #     identifier:r52
  #     identifier:document:"Some document"
  #     identifier:version:1.0.0
  #     identifier:source:some/file
  def parse_redmine_links(text, default_project, obj, attr, only_path, options)
    text.gsub!(LINKS_RE) do |_|
      tag_content = $~[:tag_content]
      leading = $~[:leading]
      esc = $~[:esc]
      project_prefix = $~[:project_prefix]
      project_identifier = $~[:project_identifier]
      prefix = $~[:prefix]
      repo_prefix = $~[:repo_prefix]
      repo_identifier = $~[:repo_identifier]
      sep = $~[:sep1] || $~[:sep2] || $~[:sep3] || $~[:sep4]
      identifier = $~[:identifier1] || $~[:identifier2] || $~[:identifier3]
      comment_suffix = $~[:comment_suffix]
      comment_id = $~[:comment_id]

      if tag_content
        $&
      else
        link = nil
        project = default_project
        if project_identifier
          project = Project.visible.find_by_identifier(project_identifier)
        end
        if esc.nil?
          if prefix.nil? && sep == 'r'
            if project
              repository = nil
              if repo_identifier
                repository = project.repositories.detect {|repo| repo.identifier == repo_identifier}
              else
                repository = project.repository
              end
              # project.changesets.visible raises an SQL error because of a double join on repositories
              if repository &&
                   (changeset = Changeset.visible.
                                    find_by_repository_id_and_revision(repository.id, identifier))
                link = link_to(h("#{project_prefix}#{repo_prefix}r#{identifier}"),
                               {:only_path => only_path, :controller => 'repositories',
                                :action => 'revision', :id => project,
                                :repository_id => repository.identifier_param,
                                :rev => changeset.revision},
                               :class => 'changeset',
                               :title => truncate_single_line_raw(changeset.comments, 100))
              end
            end
          elsif sep == '#' || sep == '##'
            oid = identifier.to_i
            case prefix
            when nil
              if oid.to_s == identifier &&
                issue = Issue.visible.find_by_id(oid)
                anchor = comment_id ? "note-#{comment_id}" : nil
                url = issue_url(issue, :only_path => only_path, :anchor => anchor)
                link = if sep == '##'
                  link_to("#{issue.tracker.name} ##{oid}#{comment_suffix}",
                          url,
                          :class => issue.css_classes,
                          :title => "#{issue.tracker.name}: #{issue.subject.truncate(100)} (#{issue.status.name})") + ": #{issue.subject}"
                else
                  link_to("##{oid}#{comment_suffix}",
                          url,
                          :class => issue.css_classes,
                          :title => "#{issue.tracker.name}: #{issue.subject.truncate(100)} (#{issue.status.name})")
                end
              end
            when 'document'
              if document = Document.visible.find_by_id(oid)
                link = link_to(document.title, document_url(document, :only_path => only_path), :class => 'document')
              end
            when 'version'
              if version = Version.visible.find_by_id(oid)
                link = link_to(version.name, version_url(version, :only_path => only_path), :class => 'version')
              end
            when 'message'
              if message = Message.visible.find_by_id(oid)
                link = link_to_message(message, {:only_path => only_path}, :class => 'message')
              end
            when 'forum'
              if board = Board.visible.find_by_id(oid)
                link = link_to(board.name, project_board_url(board.project, board, :only_path => only_path), :class => 'board')
              end
            when 'news'
              if news = News.visible.find_by_id(oid)
                link = link_to(news.title, news_url(news, :only_path => only_path), :class => 'news')
              end
            when 'project'
              if p = Project.visible.find_by_id(oid)
                link = link_to_project(p, {:only_path => only_path}, :class => 'project')
              end
            when 'user'
              u = User.visible.find_by(:id => oid, :type => 'User')
              link = link_to_user(u, :only_path => only_path) if u
            end
          elsif sep == ':'
            name = remove_double_quotes(identifier)
            case prefix
            when 'document'
              if project && document = project.documents.visible.find_by_title(name)
                link = link_to(document.title, document_url(document, :only_path => only_path), :class => 'document')
              end
            when 'version'
              if project && version = project.versions.visible.find_by_name(name)
                link = link_to(version.name, version_url(version, :only_path => only_path), :class => 'version')
              end
            when 'forum'
              if project && board = project.boards.visible.find_by_name(name)
                link = link_to(board.name, project_board_url(board.project, board, :only_path => only_path), :class => 'board')
              end
            when 'news'
              if project && news = project.news.visible.find_by_title(name)
                link = link_to(news.title, news_url(news, :only_path => only_path), :class => 'news')
              end
            when 'commit', 'source', 'export'
              if project
                repository = nil
                if name =~ %r{^(([a-z0-9\-_]+)\|)(.+)$}
                  repo_prefix, repo_identifier, name = $1, $2, $3
                  repository = project.repositories.detect {|repo| repo.identifier == repo_identifier}
                else
                  repository = project.repository
                end
                if prefix == 'commit'
                  if repository && (changeset = Changeset.visible.where("repository_id = ? AND scmid LIKE ?", repository.id, "#{name}%").first)
                    link = link_to h("#{project_prefix}#{repo_prefix}#{name}"), {:only_path => only_path, :controller => 'repositories', :action => 'revision', :id => project, :repository_id => repository.identifier_param, :rev => changeset.identifier},
                                                 :class => 'changeset',
                                                 :title => truncate_single_line_raw(changeset.comments, 100)
                  end
                else
                  if repository && User.current.allowed_to?(:browse_repository, project)
                    name =~ %r{^[/\\]*(.*?)(@([^/\\@]+?))?(#(L\d+))?$}
                    path, rev, anchor = $1, $3, $5
                    link = link_to h("#{project_prefix}#{prefix}:#{repo_prefix}#{name}"), {:only_path => only_path, :controller => 'repositories', :action => (prefix == 'export' ? 'raw' : 'entry'), :id => project, :repository_id => repository.identifier_param,
                                                            :path => to_path_param(path),
                                                            :rev => rev,
                                                            :anchor => anchor},
                                                           :class => (prefix == 'export' ? 'source download' : 'source')
                  end
                end
                repo_prefix = nil
              end
            when 'attachment'
              attachments = options[:attachments] || []
              attachments += obj.attachments if obj.respond_to?(:attachments)
              if attachments && attachment = Attachment.latest_attach(attachments, name)
                link = link_to_attachment(attachment, :only_path => only_path, :class => 'attachment')
              end
            when 'project'
              if p = Project.visible.where("identifier = :s OR LOWER(name) = :s", :s => name.downcase).first
                link = link_to_project(p, {:only_path => only_path}, :class => 'project')
              end
            when 'user'
              u = User.visible.find_by("LOWER(login) = :s AND type = 'User'", :s => name.downcase)
              link = link_to_user(u, :only_path => only_path) if u
            end
          elsif sep == "@"
            name = remove_double_quotes(identifier)
            u = User.visible.find_by("LOWER(login) = :s AND type = 'User'", :s => name.downcase)
            link = link_to_user(u, :only_path => only_path) if u
          end
        end
        (leading + (link || "#{project_prefix}#{prefix}#{repo_prefix}#{sep}#{identifier}#{comment_suffix}"))
      end
    end
  end

  LINKS_RE =
      %r{
            <a( [^>]+?)?>(?<tag_content>.*?)</a>|
            (?<leading>[\s\(,\-\[\>]|^)
            (?<esc>!)?
            (?<project_prefix>(?<project_identifier>[a-z0-9\-_]+):)?
            (?<prefix>attachment|document|version|forum|news|message|project|commit|source|export|user)?
            (
              (
                (?<sep1>\#\#?)|
                (
                  (?<repo_prefix>(?<repo_identifier>[a-z0-9\-_]+)\|)?
                  (?<sep2>r)
                )
              )
              (
                (?<identifier1>\d+)
                (?<comment_suffix>
                  (\#note)?
                  -(?<comment_id>\d+)
                )?
              )|
              (
              (?<sep3>:)
              (?<identifier2>[^"\s<>][^\s<>]*?|"[^"]+?")
              )|
              (
              (?<sep4>@)
              (?<identifier3>[A-Za-z0-9_\-@\.]*)
              )
            )
            (?=
              (?=[[:punct:]][^A-Za-z0-9_/])|
              ,|
              \s|
              \]|
              <|
              $)
      }x
  HEADING_RE = /(<h(\d)( [^>]+)?>(.+?)<\/h(\d)>)/i unless const_defined?(:HEADING_RE)

  def parse_sections(text, project, obj, attr, only_path, options)
    return unless options[:edit_section_links]
    text.gsub!(HEADING_RE) do
      heading, level = $1, $2
      @current_section += 1
      if @current_section > 1
        content_tag('div',
          link_to(l(:button_edit_section), options[:edit_section_links].merge(:section => @current_section),
                  :class => 'icon-only icon-edit'),
          :class => "contextual heading-#{level}",
          :title => l(:button_edit_section),
          :id => "section-#{@current_section}") + heading.html_safe
      else
        heading
      end
    end
  end

  # Headings and TOC
  # Adds ids and links to headings unless options[:headings] is set to false
  def parse_headings(text, project, obj, attr, only_path, options)
    return if options[:headings] == false

    text.gsub!(HEADING_RE) do
      level, attrs, content = $2.to_i, $3, $4
      item = strip_tags(content).strip
      anchor = sanitize_anchor_name(item)
      # used for single-file wiki export
      anchor = "#{obj.page.title}_#{anchor}" if options[:wiki_links] == :anchor && (obj.is_a?(WikiContent) || obj.is_a?(WikiContent::Version))
      @heading_anchors[anchor] ||= 0
      idx = (@heading_anchors[anchor] += 1)
      if idx > 1
        anchor = "#{anchor}-#{idx}"
      end
      @parsed_headings << [level, anchor, item]
      "<a name=\"#{anchor}\"></a>\n<h#{level} #{attrs}>#{content}<a href=\"##{anchor}\" class=\"wiki-anchor\">&para;</a></h#{level}>"
    end
  end

  MACROS_RE = /(
                (!)?                        # escaping
                (
                \{\{                        # opening tag
                ([\w]+)                     # macro name
                (\(([^\n\r]*?)\))?          # optional arguments
                ([\n\r].*?[\n\r])?          # optional block of text
                \}\}                        # closing tag
                )
               )/mx unless const_defined?(:MACROS_RE)

  MACRO_SUB_RE = /(
                  \{\{
                  macro\((\d+)\)
                  \}\}
                  )/x unless const_defined?(:MACRO_SUB_RE)

  # Extracts macros from text
  def catch_macros(text)
    macros = {}
    text.gsub!(MACROS_RE) do
      all, macro = $1, $4.downcase
      if macro_exists?(macro) || all =~ MACRO_SUB_RE
        index = macros.size
        macros[index] = all
        "{{macro(#{index})}}"
      else
        all
      end
    end
    macros
  end

  # Executes and replaces macros in text
  def inject_macros(text, obj, macros, execute=true)
    text.gsub!(MACRO_SUB_RE) do
      all, index = $1, $2.to_i
      orig = macros.delete(index)
      if execute && orig && orig =~ MACROS_RE
        esc, all, macro, args, block = $2, $3, $4.downcase, $6.to_s, $7.try(:strip)
        if esc.nil?
          h(exec_macro(macro, obj, args, block) || all)
        else
          h(all)
        end
      elsif orig
        h(orig)
      else
        h(all)
      end
    end
  end

  TOC_RE = /<p>\{\{((<|&lt;)|(>|&gt;))?toc\}\}<\/p>/i unless const_defined?(:TOC_RE)

  # Renders the TOC with given headings
  def replace_toc(text, headings)
    text.gsub!(TOC_RE) do
      left_align, right_align = $2, $3
      # Keep only the 4 first levels
      headings = headings.select{|level, anchor, item| level <= 4}
      if headings.empty?
        ''
      else
        div_class = 'toc'
        div_class << ' right' if right_align
        div_class << ' left' if left_align
        out = "<ul class=\"#{div_class}\"><li><strong>#{l :label_table_of_contents}</strong></li><li>"
        root = headings.map(&:first).min
        current = root
        started = false
        headings.each do |level, anchor, item|
          if level > current
            out << '<ul><li>' * (level - current)
          elsif level < current
            out << "</li></ul>\n" * (current - level) + "</li><li>"
          elsif started
            out << '</li><li>'
          end
          out << "<a href=\"##{anchor}\">#{item}</a>"
          current = level
          started = true
        end
        out << '</li></ul>' * (current - root)
        out << '</li></ul>'
      end
    end
  end

  # Same as Rails' simple_format helper without using paragraphs
  def simple_format_without_paragraph(text)
    text.to_s.
      gsub(/\r\n?/, "\n").                    # \r\n and \r -> \n
      gsub(/\n\n+/, "<br /><br />").          # 2+ newline  -> 2 br
      gsub(/([^\n]\n)(?=[^\n])/, '\1<br />'). # 1 newline   -> br
      html_safe
  end

  def lang_options_for_select(blank=true)
    (blank ? [["(auto)", ""]] : []) + languages_options
  end

  def labelled_form_for(*args, &proc)
    args << {} unless args.last.is_a?(Hash)
    options = args.last
    if args.first.is_a?(Symbol)
      options.merge!(:as => args.shift)
    end
    options.merge!({:builder => Redmine::Views::LabelledFormBuilder})
    form_for(*args, &proc)
  end

  def labelled_fields_for(*args, &proc)
    args << {} unless args.last.is_a?(Hash)
    options = args.last
    options.merge!({:builder => Redmine::Views::LabelledFormBuilder})
    fields_for(*args, &proc)
  end

  # Render the error messages for the given objects
  def error_messages_for(*objects)
    objects = objects.map {|o| o.is_a?(String) ? instance_variable_get("@#{o}") : o}.compact
    errors = objects.map {|o| o.errors.full_messages}.flatten
    render_error_messages(errors)
  end

  # Renders a list of error messages
  def render_error_messages(errors)
    html = ""
    if errors.present?
      html << "<div id='errorExplanation'><ul>\n"
      errors.each do |error|
        html << "<li>#{h error}</li>\n"
      end
      html << "</ul></div>\n"
    end
    html.html_safe
  end

  def delete_link(url, options={})
    options = {
      :method => :delete,
      :data => {:confirm => l(:text_are_you_sure)},
      :class => 'icon icon-del'
    }.merge(options)

    link_to l(:button_delete), url, options
  end

  def link_to_function(name, function, html_options={})
    content_tag(:a, name, {:href => '#', :onclick => "#{function}; return false;"}.merge(html_options))
  end

  def link_to_context_menu
    link_to l(:button_actions), '#', title: l(:button_actions), class: 'icon-only icon-actions js-contextmenu'
  end

  # Helper to render JSON in views
  def raw_json(arg)
    arg.to_json.to_s.gsub('/', '\/').html_safe
  end

  def back_url
    url = params[:back_url]
    if url.nil? && referer = request.env['HTTP_REFERER']
      url = CGI.unescape(referer.to_s)
      # URLs that contains the utf8=[checkmark] parameter added by Rails are
      # parsed as invalid by URI.parse so the redirect to the back URL would
      # not be accepted (ApplicationController#validate_back_url would return
      # false)
      url.gsub!(/(\?|&)utf8=\u2713&?/, '\1')
    end
    url
  end

  def back_url_hidden_field_tag
    url = back_url
    hidden_field_tag('back_url', url, :id => nil) unless url.blank?
  end

  def cancel_button_tag(fallback_url)
    url = back_url.blank? ? fallback_url : back_url
    link_to l(:button_cancel), url
  end

  def check_all_links(form_name)
    link_to_function(l(:button_check_all), "checkAll('#{form_name}', true)") +
    " | ".html_safe +
    link_to_function(l(:button_uncheck_all), "checkAll('#{form_name}', false)")
  end

  def toggle_checkboxes_link(selector)
    link_to_function '',
      "toggleCheckboxesBySelector('#{selector}')",
      :title => "#{l(:button_check_all)} / #{l(:button_uncheck_all)}",
      :class => 'icon icon-checked'
  end

  def progress_bar(pcts, options={})
    pcts = [pcts, pcts] unless pcts.is_a?(Array)
    pcts = pcts.collect(&:round)
    pcts[1] = pcts[1] - pcts[0]
    pcts << (100 - pcts[1] - pcts[0])
    titles = options[:titles].to_a
    titles[0] = "#{pcts[0]}%" if titles[0].blank?
    legend = options[:legend] || ''
    content_tag('table',
      content_tag('tr',
        (pcts[0] > 0 ? content_tag('td', '', :style => "width: #{pcts[0]}%;", :class => 'closed', :title => titles[0]) : ''.html_safe) +
        (pcts[1] > 0 ? content_tag('td', '', :style => "width: #{pcts[1]}%;", :class => 'done', :title => titles[1]) : ''.html_safe) +
        (pcts[2] > 0 ? content_tag('td', '', :style => "width: #{pcts[2]}%;", :class => 'todo', :title => titles[2]) : ''.html_safe)
      ), :class => "progress progress-#{pcts[0]}").html_safe +
      content_tag('p', legend, :class => 'percent').html_safe
  end

  def checked_image(checked=true)
    if checked
      @checked_image_tag ||= content_tag(:span, nil, :class => 'icon-only icon-checked')
    end
  end

  def context_menu
    unless @context_menu_included
      content_for :header_tags do
        javascript_include_tag('context_menu') +
          stylesheet_link_tag('context_menu')
      end
      if l(:direction) == 'rtl'
        content_for :header_tags do
          stylesheet_link_tag('context_menu_rtl')
        end
      end
      @context_menu_included = true
    end
    nil
  end

  def calendar_for(field_id)
    include_calendar_headers_tags
    javascript_tag("$(function() { $('##{field_id}').addClass('date').datepickerFallback(datepickerOptions); });")
  end

  def include_calendar_headers_tags
    unless @calendar_headers_tags_included
      tags = ''.html_safe
      @calendar_headers_tags_included = true
      content_for :header_tags do
        start_of_week = Setting.start_of_week
        start_of_week = l(:general_first_day_of_week, :default => '1') if start_of_week.blank?
        # Redmine uses 1..7 (monday..sunday) in settings and locales
        # JQuery uses 0..6 (sunday..saturday), 7 needs to be changed to 0
        start_of_week = start_of_week.to_i % 7
        tags << javascript_tag(
                   "var datepickerOptions={dateFormat: 'yy-mm-dd', firstDay: #{start_of_week}, " +
                     "showOn: 'button', buttonImageOnly: true, buttonImage: '" +
                     path_to_image('/images/calendar.png') +
                     "', showButtonPanel: true, showWeek: true, showOtherMonths: true, " +
                     "selectOtherMonths: true, changeMonth: true, changeYear: true, " +
                     "beforeShow: beforeShowDatePicker};")
        jquery_locale = l('jquery.locale', :default => current_language.to_s)
        unless jquery_locale == 'en'
          tags << javascript_include_tag("i18n/datepicker-#{jquery_locale}.js")
        end
        tags
      end
    end
  end

  # Overrides Rails' stylesheet_link_tag with themes and plugins support.
  # Examples:
  #   stylesheet_link_tag('styles') # => picks styles.css from the current theme or defaults
  #   stylesheet_link_tag('styles', :plugin => 'foo) # => picks styles.css from plugin's assets
  #
  def stylesheet_link_tag(*sources)
    options = sources.last.is_a?(Hash) ? sources.pop : {}
    plugin = options.delete(:plugin)
    sources = sources.map do |source|
      if plugin
        "/plugin_assets/#{plugin}/stylesheets/#{source}"
      elsif current_theme && current_theme.stylesheets.include?(source)
        current_theme.stylesheet_path(source)
      else
        source
      end
    end
    super *sources, options
  end

  # Overrides Rails' image_tag with themes and plugins support.
  # Examples:
  #   image_tag('image.png') # => picks image.png from the current theme or defaults
  #   image_tag('image.png', :plugin => 'foo) # => picks image.png from plugin's assets
  #
  def image_tag(source, options={})
    if plugin = options.delete(:plugin)
      source = "/plugin_assets/#{plugin}/images/#{source}"
    elsif current_theme && current_theme.images.include?(source)
      source = current_theme.image_path(source)
    end
    super source, options
  end

  # Overrides Rails' javascript_include_tag with plugins support
  # Examples:
  #   javascript_include_tag('scripts') # => picks scripts.js from defaults
  #   javascript_include_tag('scripts', :plugin => 'foo) # => picks scripts.js from plugin's assets
  #
  def javascript_include_tag(*sources)
    options = sources.last.is_a?(Hash) ? sources.pop : {}
    if plugin = options.delete(:plugin)
      sources = sources.map do |source|
        if plugin
          "/plugin_assets/#{plugin}/javascripts/#{source}"
        else
          source
        end
      end
    end
    super *sources, options
  end

  def sidebar_content?
    content_for?(:sidebar) || view_layouts_base_sidebar_hook_response.present?
  end

  def view_layouts_base_sidebar_hook_response
    @view_layouts_base_sidebar_hook_response ||= call_hook(:view_layouts_base_sidebar)
  end

  def email_delivery_enabled?
    !!ActionMailer::Base.perform_deliveries
  end

  # Returns the avatar image tag for the given +user+ if avatars are enabled
  # +user+ can be a User or a string that will be scanned for an email address (eg. 'joe <joe@foo.bar>')
  def avatar(user, options = { })
    if Setting.gravatar_enabled?
      options.merge!(:default => Setting.gravatar_default)
      email = nil
      if user.respond_to?(:mail)
        email = user.mail
      elsif user.to_s =~ %r{<(.+?)>}
        email = $1
      end
      if email.present?
        gravatar(email.to_s.downcase, options) rescue nil
      elsif user.is_a?(AnonymousUser)
        image_tag 'anonymous.png',
                  GravatarHelper::DEFAULT_OPTIONS
                    .except(:default, :rating, :ssl).merge(options)
      else
        nil
      end
    else
      ''
    end
  end

  # Returns a link to edit user's avatar if avatars are enabled
  def avatar_edit_link(user, options={})
    if Setting.gravatar_enabled?
      url = "https://gravatar.com"
      link_to avatar(user, {:title => l(:button_edit)}.merge(options)), url, :target => '_blank'
    end
  end

  def sanitize_anchor_name(anchor)
    anchor.gsub(%r{[^\s\-\p{Word}]}, '').gsub(%r{\s+(\-+\s*)?}, '-')
  end

  # Returns the javascript tags that are included in the html layout head
  def javascript_heads
    tags = javascript_include_tag('jquery-1.11.1-ui-1.11.0-ujs-4.3.1', 'application', 'responsive')
    unless User.current.pref.warn_on_leaving_unsaved == '0'
      tags << "\n".html_safe + javascript_tag("$(window).load(function(){ warnLeavingUnsaved('#{escape_javascript l(:text_warn_on_leaving_unsaved)}'); });")
    end
    tags
  end

  def favicon
    "<link rel='shortcut icon' href='#{favicon_path}' />".html_safe
  end

  # Returns the path to the favicon
  def favicon_path
    icon = (current_theme && current_theme.favicon?) ? current_theme.favicon_path : '/favicon.ico'
    image_path(icon)
  end

  # Returns the full URL to the favicon
  def favicon_url
    # TODO: use #image_url introduced in Rails4
    path = favicon_path
    base = url_for(:controller => 'welcome', :action => 'index', :only_path => false)
    base.sub(%r{/+$},'') + '/' + path.sub(%r{^/+},'')
  end

  def robot_exclusion_tag
    '<meta name="robots" content="noindex,follow,noarchive" />'.html_safe
  end

  # Returns true if arg is expected in the API response
  def include_in_api_response?(arg)
    unless @included_in_api_response
      param = params[:include]
      @included_in_api_response = param.is_a?(Array) ? param.collect(&:to_s) : param.to_s.split(',')
      @included_in_api_response.collect!(&:strip)
    end
    @included_in_api_response.include?(arg.to_s)
  end

  # Returns options or nil if nometa param or X-Redmine-Nometa header
  # was set in the request
  def api_meta(options)
    if params[:nometa].present? || request.headers['X-Redmine-Nometa']
      # compatibility mode for activeresource clients that raise
      # an error when deserializing an array with attributes
      nil
    else
      options
    end
  end

  def generate_csv(&block)
    decimal_separator = l(:general_csv_decimal_separator)
    encoding = l(:general_csv_encoding)
  end

  def export_csv_encoding_select_tag
    return if l(:general_csv_encoding).casecmp('UTF-8') == 0
    options = [l(:general_csv_encoding), 'UTF-8']
    content_tag(:p) do
      concat(
        content_tag(:label) do
          concat l(:label_encoding) + ' '
          concat select_tag('encoding', options_for_select(options, l(:general_csv_encoding)))
        end
      )
    end
  end

  # Returns an array of error messages for bulk edited items (issues, time entries)
  def bulk_edit_error_messages(items)
    messages = {}
    items.each do |item|
      item.errors.full_messages.each do |message|
        messages[message] ||= []
        messages[message] << item
      end
    end
    messages.map { |message, items|
      "#{message}: " + items.map {|i| "##{i.id}"}.join(', ')
    }
  end

  private

  def wiki_helper
    helper = Redmine::WikiFormatting.helper_for(Setting.text_formatting)
    extend helper
    return self
  end

  # remove double quotes if any
  def remove_double_quotes(identifier)
    name = identifier.gsub(%r{^"(.*)"$}, "\\1")
    return CGI.unescapeHTML(name)
  end
end
