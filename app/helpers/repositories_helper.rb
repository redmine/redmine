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

module RepositoriesHelper
  def format_revision(revision)
    if revision.respond_to? :format_identifier
      revision.format_identifier
    else
      revision.to_s
    end
  end

  def truncate_at_line_break(text, length = 255)
    if text
      text.gsub(%r{^(.{#{length}}[^\n]*)\n.+$}m, '\\1...')
    end
  end

  def render_properties(properties)
    unless properties.nil? || properties.empty?
      content = ''
      properties.keys.sort.each do |property|
        content << content_tag('li', "<b>#{h property}</b>: <span>#{h properties[property]}</span>".html_safe)
      end
      content_tag('ul', content.html_safe, :class => 'properties')
    end
  end

  def render_changeset_changes
    changes = @changeset.filechanges.limit(1000).reorder('path').collect do |change|
      case change.action
      when 'A'
        # Detects moved/copied files
        if !change.from_path.blank?
          change.action =
             @changeset.filechanges.detect {|c| c.action == 'D' && c.path == change.from_path} ? 'R' : 'C'
        end
        change
      when 'D'
        @changeset.filechanges.detect {|c| c.from_path == change.path} ? nil : change
      else
        change
      end
    end.compact

    tree = { }
    changes.each do |change|
      p = tree
      dirs = change.path.to_s.split('/').select {|d| !d.blank?}
      path = ''
      dirs.each do |dir|
        path += '/' + dir
        p[:s] ||= {}
        p = p[:s]
        p[path] ||= {}
        p = p[path]
      end
      p[:c] = change
    end
    render_changes_tree(tree[:s])
  end

  def render_changes_tree(tree)
    return '' if tree.nil?
    output = ''
    output << '<ul>'
    tree.keys.sort.each do |file|
      style = 'change'
      text = File.basename(h(file))
      if s = tree[file][:s]
        style << ' folder'
        path_param = to_path_param(@repository.relative_path(file))
        text = link_to(h(text), :controller => 'repositories',
                             :action => 'show',
                             :id => @project,
                             :repository_id => @repository.identifier_param,
                             :path => path_param,
                             :rev => @changeset.identifier)
        output << "<li class='#{style}'>#{text}"
        output << render_changes_tree(s)
        output << "</li>"
      elsif c = tree[file][:c]
        style << " change-#{c.action}"
        path_param = to_path_param(@repository.relative_path(c.path))
        text = link_to(h(text), :controller => 'repositories',
                             :action => 'entry',
                             :id => @project,
                             :repository_id => @repository.identifier_param,
                             :path => path_param,
                             :rev => @changeset.identifier) unless c.action == 'D'
        text << " - #{h(c.revision)}" unless c.revision.blank?
        text << ' ('.html_safe + link_to(l(:label_diff), :controller => 'repositories',
                                       :action => 'diff',
                                       :id => @project,
                                       :repository_id => @repository.identifier_param,
                                       :path => path_param,
                                       :rev => @changeset.identifier) + ') '.html_safe if c.action == 'M'
        text << ' '.html_safe + content_tag('span', h(c.from_path), :class => 'copied-from') unless c.from_path.blank?
        output << "<li class='#{style}'>#{text}</li>"
      end
    end
    output << '</ul>'
    output.html_safe
  end

  def repository_field_tags(form, repository)
    method = repository.class.name.demodulize.underscore + "_field_tags"
    if repository.is_a?(Repository) &&
        respond_to?(method) && method != 'repository_field_tags'
      send(method, form, repository)
    end
  end

  def scm_select_tag(repository)
    scm_options = [["--- #{l(:actionview_instancetag_blank_option)} ---", '']]
    Redmine::Scm::Base.all.each do |scm|
    if Setting.enabled_scm.include?(scm) ||
          (repository && repository.class.name.demodulize == scm)
        scm_options << ["Repository::#{scm}".constantize.scm_name, scm]
      end
    end
    select_tag('repository_scm',
               options_for_select(scm_options, repository.class.name.demodulize),
               :disabled => (repository && !repository.new_record?),
               :data => {:remote => true, :method => 'get'})
  end

  def with_leading_slash(path)
    path.to_s.starts_with?('/') ? path : "/#{path}"
  end

  def subversion_field_tags(form, repository)
      content_tag('p', form.text_field(:url, :size => 60, :required => true,
                       :disabled => !repository.safe_attribute?('url')) +
                       scm_path_info_tag(repository)) +
      content_tag('p', form.text_field(:login, :size => 30)) +
      content_tag('p', form.password_field(
                            :password, :size => 30, :name => 'ignore',
                            :value => ((repository.new_record? || repository.password.blank?) ? '' : ('x'*15)),
                            :onfocus => "this.value=''; this.name='repository[password]';",
                            :onchange => "this.name='repository[password]';"))
  end

  def darcs_field_tags(form, repository)
    content_tag('p', form.text_field(
                     :url, :label => l(:field_path_to_repository),
                     :size => 60, :required => true,
                     :disabled => !repository.safe_attribute?('url')) +
                     scm_path_info_tag(repository)) +
    scm_log_encoding_tag(form, repository)
  end

  def mercurial_field_tags(form, repository)
    content_tag('p', form.text_field(
                       :url, :label => l(:field_path_to_repository),
                       :size => 60, :required => true,
                       :disabled => !repository.safe_attribute?('url')
                         ) +
                     scm_path_info_tag(repository)) +
    scm_path_encoding_tag(form, repository)
  end

  def git_field_tags(form, repository)
    content_tag('p', form.text_field(
                       :url, :label => l(:field_path_to_repository),
                       :size => 60, :required => true,
                       :disabled => !repository.safe_attribute?('url')
                         ) +
                      scm_path_info_tag(repository)) +
    scm_path_encoding_tag(form, repository) +
    content_tag('p', form.check_box(
                        :extra_report_last_commit,
                        :label => l(:label_git_report_last_commit)
                         ))
  end

  def cvs_field_tags(form, repository)
    content_tag('p', form.text_field(
                     :root_url,
                     :label => l(:field_cvsroot),
                     :size => 60, :required => true,
                     :disabled => !repository.safe_attribute?('root_url')) +
                     scm_path_info_tag(repository)) +
    content_tag('p', form.text_field(
                     :url,
                     :label => l(:field_cvs_module),
                     :size => 30, :required => true,
                     :disabled => !repository.safe_attribute?('url'))) +
    scm_log_encoding_tag(form, repository) +
    scm_path_encoding_tag(form, repository)
  end

  def bazaar_field_tags(form, repository)
    content_tag('p', form.text_field(
                     :url, :label => l(:field_path_to_repository),
                     :size => 60, :required => true,
                     :disabled => !repository.safe_attribute?('url')) +
                     scm_path_info_tag(repository)) +
    scm_log_encoding_tag(form, repository)
  end

  def filesystem_field_tags(form, repository)
    content_tag('p', form.text_field(
                     :url, :label => l(:field_root_directory),
                     :size => 60, :required => true,
                     :disabled => !repository.safe_attribute?('url')) +
                     scm_path_info_tag(repository)) +
    scm_path_encoding_tag(form, repository)
  end

  def scm_path_info_tag(repository)
    text = scm_path_info(repository)
    if text.present?
      content_tag('em', text, :class => 'info')
    else
      ''
    end
  end

  def scm_path_info(repository)
    scm_name = repository.scm_name.to_s.downcase

    info_from_config = Redmine::Configuration["scm_#{scm_name}_path_info"].presence
    return info_from_config.html_safe if info_from_config

    l("text_#{scm_name}_repository_note", :default => '')
  end

  def scm_log_encoding_tag(form, repository)
    select = form.select(
      :log_encoding,
      [nil] + Setting::ENCODINGS,
      :label => l(:field_commit_logs_encoding),
      :required => true
    )
    content_tag('p', select)
  end

  def scm_path_encoding_tag(form, repository)
    select = form.select(
      :path_encoding,
      [nil] + Setting::ENCODINGS,
      :label => l(:field_scm_path_encoding)
    )
    content_tag('p', select + content_tag('em', l(:text_scm_path_encoding_note), :class => 'info'))
  end

  def index_commits(commits, heads)
    return nil if commits.nil? or commits.first.parents.nil?
    refs_map = {}
    heads.each do |head|
      refs_map[head.scmid] ||= []
      refs_map[head.scmid] << head
    end
    commits_by_scmid = {}
    commits.reverse.each_with_index do |commit, commit_index|
      commits_by_scmid[commit.scmid] = {
        :parent_scmids => commit.parents.collect { |parent| parent.scmid },
        :rdmid => commit_index,
        :refs  => refs_map.include?(commit.scmid) ? refs_map[commit.scmid].join(" ") : nil,
        :scmid => commit.scmid,
        :href  => block_given? ? yield(commit.scmid) : commit.scmid
      }
    end
    heads.sort! { |head1, head2| head1.to_s <=> head2.to_s }
    space = nil  
    heads.each do |head|
      if commits_by_scmid.include? head.scmid
        space = index_head((space || -1) + 1, head, commits_by_scmid)
      end
    end
    # when no head matched anything use first commit
    space ||= index_head(0, commits.first, commits_by_scmid)
    return commits_by_scmid, space
  end

  def index_head(space, commit, commits_by_scmid)
    stack = [[space, commits_by_scmid[commit.scmid]]]
    max_space = space
    until stack.empty?
      space, commit = stack.pop
      commit[:space] = space if commit[:space].nil?
      space -= 1
      commit[:parent_scmids].each_with_index do |parent_scmid, parent_index|
        parent_commit = commits_by_scmid[parent_scmid]
        if parent_commit and parent_commit[:space].nil?
          stack.unshift [space += 1, parent_commit]
        end
      end
      max_space = space if max_space < space
    end
    max_space
  end
end
