# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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
        link_to name, user_path(user), :class => user.css_classes
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
    route_method = options.delete(:download) ? :download_named_attachment_url : :named_attachment_url
    html_options = options.slice!(:only_path)
    options[:only_path] = true unless options.key?(:only_path)
    url = send(route_method, attachment, attachment.filename, options)
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

  # Helper that formats object for html or text rendering
  def format_object(object, html=true, &block)
    if block_given?
      object = yield object
    end
    case object.class.name
    when 'Array'
      object.map {|o| format_object(o, html)}.join(', ').html_safe
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
    link_to image_tag(thumbnail_path(attachment)),
      named_attachment_path(attachment, attachment.filename),
      :title => attachment.filename
  end

  def toggle_link(name, id, options={})
    onclick = "$('##{id}').toggle(); "
    onclick << (options[:focus] ? "$('##{options[:focus]}').focus(); " : "this.blur(); ")
    onclick << "return false;"
    link_to(name, "#", :onclick => onclick)
  end

  def format_activity_title(text)
    h(truncate_single_line_raw(text, 100))
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

  def due_date_distance_in_words(date)
    if date
      l((date < Date.today ? :label_roadmap_overdue : :label_roadmap_due_in), distance_of_date_in_words(Date.today, date))
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

  # Renders the project quick-jump box
  def render_project_jump_box
    return unless User.current.logged?
    projects = User.current.projects.active.select(:id, :name, :identifier, :lft, :rgt).to_a
    if projects.any?
      options =
        ("<option value=''>#{ l(:label_jump_to_a_project) }</option>" +
         '<option value="" disabled="disabled">---</option>').html_safe

      options << project_tree_options_for_select(projects, :selected => @project) do |p|
        { :value => project_path(:id => p, :jump => current_menu_item) }
      end

      select_tag('project_quick_jump_box', options, :onchange => 'if (this.value != \'\') { window.location = this.value; }')
    end
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
  def project_tree(projects, &block)
    Project.project_tree(projects, &block)
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
    text.to_s.gsub(' ', '_')
  end

  def html_hours(text)
    text.gsub(%r{(\d+)\.(\d+)}, '<span class="hours hours-int">\1</span><span class="hours hours-dec">.\2</span>').html_safe
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
    lines = []
    syntax_highlight(name, content).each_line { |line| lines << line }
    lines
  end

  def syntax_highlight(name, content)
    Redmine::SyntaxHighlighting.highlight_by_filename(content, name)
  end

  def to_path_param(path)
    str = path.to_s.split(%r{[/\\]}).select{|p| !p.blank?}.join("/")
    str.blank? ? nil : str
  end

  def reorder_links(name, url, method = :post)
    link_to(image_tag('2uparrow.png', :alt => l(:label_sort_highest)),
            url.merge({"#{name}[move_to]" => 'highest'}),
            :method => method, :title => l(:label_sort_highest)) +
    link_to(image_tag('1uparrow.png',   :alt => l(:label_sort_higher)),
            url.merge({"#{name}[move_to]" => 'higher'}),
           :method => method, :title => l(:label_sort_higher)) +
    link_to(image_tag('1downarrow.png', :alt => l(:label_sort_lower)),
            url.merge({"#{name}[move_to]" => 'lower'}),
            :method => method, :title => l(:label_sort_lower)) +
    link_to(image_tag('2downarrow.png', :alt => l(:label_sort_lowest)),
            url.merge({"#{name}[move_to]" => 'lowest'}),
           :method => method, :title => l(:label_sort_lowest))
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
      b << h(@project)
      b.join(" \xc2\xbb ").html_safe
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

  # Returns the theme, controller name, and action as css classes for the
  # HTML body.
  def body_css_classes
    css = []
    if theme = Redmine::Themes.theme(Setting.ui_theme)
      css << 'theme-' + theme.name
    end

    css << 'project-' + @project.identifier if @project && @project.identifier.present?
    css << 'controller-' + controller_name
    css << 'action-' + action_name
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
    text = Redmine::WikiFormatting.to_html(Setting.text_formatting, text, :object => obj, :attribute => attr)

    @parsed_headings = []
    @heading_anchors = {}
    @current_section = 0 if options[:edit_section_links]

    parse_sections(text, project, obj, attr, only_path, options)
    text = parse_non_pre_blocks(text, obj, macros) do |text|
      [:parse_inline_attachments, :parse_wiki_links, :parse_redmine_links].each do |method_name|
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
          if tags.last == tag.downcase
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

  def parse_inline_attachments(text, project, obj, attr, only_path, options)
    return if options[:inline_attachments] == false

    # when using an image link, try to use an attachment, if possible
    attachments = options[:attachments] || []
    attachments += obj.attachments if obj.respond_to?(:attachments)
    if attachments.present?
      text.gsub!(/src="([^\/"]+\.(bmp|gif|jpg|jpe|jpeg|png))"(\s+alt="([^"]*)")?/i) do |m|
        filename, ext, alt, alttext = $1.downcase, $2, $3, $4
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
    text.gsub!(/(!)?(\[\[([^\]\n\|]+)(\|([^\]\n\|]+))?\]\])/) do |m|
      link_project = project
      esc, all, page, title = $1, $2, $3, $5
      if esc.nil?
        if page =~ /^([^\:]+)\:(.*)$/
          identifier, page = $1, $2
          link_project = Project.find_by_identifier(identifier) || Project.find_by_name(identifier)
          title ||= identifier if page.blank?
        end

        if link_project && link_project.wiki
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
  #   Forum messages:
  #     message#1218 -> Link to message with id 1218
  #  Projects:
  #     project:someproject -> Link to project named "someproject"
  #     project#3 -> Link to project with id 3
  #
  #   Links can refer other objects from other projects, using project identifier:
  #     identifier:r52
  #     identifier:document:"Some document"
  #     identifier:version:1.0.0
  #     identifier:source:some/file
  def parse_redmine_links(text, default_project, obj, attr, only_path, options)
    text.gsub!(%r{<a( [^>]+?)?>(.*?)</a>|([\s\(,\-\[\>]|^)(!)?(([a-z0-9\-_]+):)?(attachment|document|version|forum|news|message|project|commit|source|export)?(((#)|((([a-z0-9\-_]+)\|)?(r)))((\d+)((#note)?-(\d+))?)|(:)([^"\s<>][^\s<>]*?|"[^"]+?"))(?=(?=[[:punct:]][^A-Za-z0-9_/])|,|\s|\]|<|$)}) do |m|
      tag_content, leading, esc, project_prefix, project_identifier, prefix, repo_prefix, repo_identifier, sep, identifier, comment_suffix, comment_id = $1, $3, $4, $5, $6, $7, $12, $13, $10 || $14 || $20, $16 || $21, $17, $19
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
          elsif sep == '#'
            oid = identifier.to_i
            case prefix
            when nil
              if oid.to_s == identifier &&
                issue = Issue.visible.find_by_id(oid)
                anchor = comment_id ? "note-#{comment_id}" : nil
                link = link_to("##{oid}#{comment_suffix}",
                               issue_url(issue, :only_path => only_path, :anchor => anchor),
                               :class => issue.css_classes,
                               :title => "#{issue.subject.truncate(100)} (#{issue.status.name})")
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
            end
          elsif sep == ':'
            # removes the double quotes if any
            name = identifier.gsub(%r{^"(.*)"$}, "\\1")
            name = CGI.unescapeHTML(name)
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
                link = link_to_attachment(attachment, :only_path => only_path, :download => true, :class => 'attachment')
              end
            when 'project'
              if p = Project.visible.where("identifier = :s OR LOWER(name) = :s", :s => name.downcase).first
                link = link_to_project(p, {:only_path => only_path}, :class => 'project')
              end
            end
          end
        end
        (leading + (link || "#{project_prefix}#{prefix}#{repo_prefix}#{sep}#{identifier}#{comment_suffix}"))
      end
    end
  end

  HEADING_RE = /(<h(\d)( [^>]+)?>(.+?)<\/h(\d)>)/i unless const_defined?(:HEADING_RE)

  def parse_sections(text, project, obj, attr, only_path, options)
    return unless options[:edit_section_links]
    text.gsub!(HEADING_RE) do
      heading = $1
      @current_section += 1
      if @current_section > 1
        content_tag('div',
          link_to(image_tag('edit.png'), options[:edit_section_links].merge(:section => @current_section)),
          :class => 'contextual',
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
        out = "<ul class=\"#{div_class}\"><li>"
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

  def error_messages_for(*objects)
    html = ""
    objects = objects.map {|o| o.is_a?(String) ? instance_variable_get("@#{o}") : o}.compact
    errors = objects.map {|o| o.errors.full_messages}.flatten
    if errors.any?
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

  def preview_link(url, form, target='preview', options={})
    content_tag 'a', l(:label_preview), {
        :href => "#",
        :onclick => %|submitPreview("#{escape_javascript url_for(url)}", "#{escape_javascript form}", "#{escape_javascript target}"); return false;|,
        :accesskey => accesskey(:preview)
      }.merge(options)
  end

  def link_to_function(name, function, html_options={})
    content_tag(:a, name, {:href => '#', :onclick => "#{function}; return false;"}.merge(html_options))
  end

  # Helper to render JSON in views
  def raw_json(arg)
    arg.to_json.to_s.gsub('/', '\/').html_safe
  end

  def back_url
    url = params[:back_url]
    if url.nil? && referer = request.env['HTTP_REFERER']
      url = CGI.unescape(referer.to_s)
    end
    url
  end

  def back_url_hidden_field_tag
    url = back_url
    hidden_field_tag('back_url', url, :id => nil) unless url.blank?
  end

  def check_all_links(form_name)
    link_to_function(l(:button_check_all), "checkAll('#{form_name}', true)") +
    " | ".html_safe +
    link_to_function(l(:button_uncheck_all), "checkAll('#{form_name}', false)")
  end

  def toggle_checkboxes_link(selector)
    link_to_function image_tag('toggle_check.png'),
      "toggleCheckboxesBySelector('#{selector}')",
      :title => "#{l(:button_check_all)} / #{l(:button_uncheck_all)}"
  end

  def progress_bar(pcts, options={})
    pcts = [pcts, pcts] unless pcts.is_a?(Array)
    pcts = pcts.collect(&:round)
    pcts[1] = pcts[1] - pcts[0]
    pcts << (100 - pcts[1] - pcts[0])
    width = options[:width] || '100px;'
    legend = options[:legend] || ''
    content_tag('table',
      content_tag('tr',
        (pcts[0] > 0 ? content_tag('td', '', :style => "width: #{pcts[0]}%;", :class => 'closed') : ''.html_safe) +
        (pcts[1] > 0 ? content_tag('td', '', :style => "width: #{pcts[1]}%;", :class => 'done') : ''.html_safe) +
        (pcts[2] > 0 ? content_tag('td', '', :style => "width: #{pcts[2]}%;", :class => 'todo') : ''.html_safe)
      ), :class => "progress progress-#{pcts[0]}", :style => "width: #{width};").html_safe +
      content_tag('p', legend, :class => 'percent').html_safe
  end

  def checked_image(checked=true)
    if checked
      image_tag 'toggle_check.png'
    end
  end

  def context_menu(url)
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
    javascript_tag "contextMenuInit('#{ url_for(url) }')"
  end

  def calendar_for(field_id)
    include_calendar_headers_tags
    javascript_tag("$(function() { $('##{field_id}').datepicker(datepickerOptions); });")
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
      options.merge!({:ssl => (request && request.ssl?), :default => Setting.gravatar_default})
      email = nil
      if user.respond_to?(:mail)
        email = user.mail
      elsif user.to_s =~ %r{<(.+?)>}
        email = $1
      end
      return gravatar(email.to_s.downcase, options) unless email.blank? rescue nil
    else
      ''
    end
  end

  def sanitize_anchor_name(anchor)
    anchor.gsub(%r{[^\s\-\p{Word}]}, '').gsub(%r{\s+(\-+\s*)?}, '-')
  end

  # Returns the javascript tags that are included in the html layout head
  def javascript_heads
    tags = javascript_include_tag('jquery-1.11.1-ui-1.11.0-ujs-3.1.1', 'application')
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

  private

  def wiki_helper
    helper = Redmine::WikiFormatting.helper_for(Setting.text_formatting)
    extend helper
    return self
  end

  def link_to_content_update(text, url_params = {}, html_options = {})
    link_to(text, url_params, html_options)
  end
end
