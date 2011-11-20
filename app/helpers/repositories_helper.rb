# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
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

require 'iconv'
require 'redmine/codeset_util'

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
    changes = @changeset.changes.find(:all, :limit => 1000, :order => 'path').collect do |change|
      case change.action
      when 'A'
        # Detects moved/copied files
        if !change.from_path.blank?
          change.action =
             @changeset.changes.detect {|c| c.action == 'D' && c.path == change.from_path} ? 'R' : 'C'
        end
        change
      when 'D'
        @changeset.changes.detect {|c| c.from_path == change.path} ? nil : change
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
                             :path => path_param,
                             :rev => @changeset.identifier)
        output << "<li class='#{style}'>#{text}</li>"
        output << render_changes_tree(s)
      elsif c = tree[file][:c]
        style << " change-#{c.action}"
        path_param = to_path_param(@repository.relative_path(c.path))
        text = link_to(h(text), :controller => 'repositories',
                             :action => 'entry',
                             :id => @project,
                             :path => path_param,
                             :rev => @changeset.identifier) unless c.action == 'D'
        text << " - #{h(c.revision)}" unless c.revision.blank?
        text << ' ('.html_safe + link_to(l(:label_diff), :controller => 'repositories',
                                       :action => 'diff',
                                       :id => @project,
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
               :onchange => remote_function(
                  :url => {
                      :controller => 'repositories',
                      :action     => 'edit',
                      :id         => @project
                   },
               :method => :get,
               :with   => "Form.serialize(this.form)")
             )
  end

  def with_leading_slash(path)
    path.to_s.starts_with?('/') ? path : "/#{path}"
  end

  def without_leading_slash(path)
    path.gsub(%r{^/+}, '')
  end

  def subversion_field_tags(form, repository)
      content_tag('p', form.text_field(:url, :size => 60, :required => true,
                       :disabled => (repository && !repository.root_url.blank?)) +
                       '<br />'.html_safe +
                       '(file:///, http://, https://, svn://, svn+[tunnelscheme]://)') +
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
                     :disabled => (repository && !repository.new_record?))) +
    content_tag('p', form.select(
                     :log_encoding, [nil] + Setting::ENCODINGS,
                     :label => l(:field_commit_logs_encoding), :required => true))
  end

  def mercurial_field_tags(form, repository)
    content_tag('p', form.text_field(
                       :url, :label => l(:field_path_to_repository),
                       :size => 60, :required => true,
                       :disabled => (repository && !repository.root_url.blank?)
                         ) +
                     '<br />'.html_safe + l(:text_mercurial_repository_note)) +
    content_tag('p', form.select(
                        :path_encoding, [nil] + Setting::ENCODINGS,
                        :label => l(:field_scm_path_encoding)
                        ) +
                     '<br />'.html_safe + l(:text_scm_path_encoding_note))
  end

  def git_field_tags(form, repository)
    content_tag('p', form.text_field(
                       :url, :label => l(:field_path_to_repository),
                       :size => 60, :required => true,
                       :disabled => (repository && !repository.root_url.blank?)
                         ) +
                      '<br />'.html_safe +
                      l(:text_git_repository_note)) +
    content_tag('p', form.select(
                        :path_encoding, [nil] + Setting::ENCODINGS,
                        :label => l(:field_scm_path_encoding)
                        ) +
                     '<br />'.html_safe + l(:text_scm_path_encoding_note)) +
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
                     :disabled => !repository.new_record?)) +
    content_tag('p', form.text_field(
                     :url,
                     :label => l(:field_cvs_module),
                     :size => 30, :required => true,
                     :disabled => !repository.new_record?)) +
    content_tag('p', form.select(
                     :log_encoding, [nil] + Setting::ENCODINGS,
                     :label => l(:field_commit_logs_encoding), :required => true)) +
    content_tag('p', form.select(
                        :path_encoding, [nil] + Setting::ENCODINGS,
                        :label => l(:field_scm_path_encoding)
                        ) +
                     '<br />'.html_safe + l(:text_scm_path_encoding_note))
  end

  def bazaar_field_tags(form, repository)
    content_tag('p', form.text_field(
                     :url, :label => l(:field_path_to_repository),
                     :size => 60, :required => true,
                     :disabled => (repository && !repository.new_record?))) +
    content_tag('p', form.select(
                     :log_encoding, [nil] + Setting::ENCODINGS,
                     :label => l(:field_commit_logs_encoding), :required => true))
  end

  def filesystem_field_tags(form, repository)
    content_tag('p', form.text_field(
                     :url, :label => l(:field_root_directory),
                     :size => 60, :required => true,
                     :disabled => (repository && !repository.root_url.blank?))) +
    content_tag('p', form.select(
                        :path_encoding, [nil] + Setting::ENCODINGS,
                        :label => l(:field_scm_path_encoding)
                        ) +
                     '<br />'.html_safe + l(:text_scm_path_encoding_note))
  end

  def index_commits(commits, heads, href_proc = nil)
    return nil if commits.nil? or commits.first.parents.nil?
    map  = {}
    commit_hashes = []
    refs_map = {}
    href_proc ||= Proc.new {|x|x}
    heads.each{|r| refs_map[r.scmid] ||= []; refs_map[r.scmid] << r}
    commits.reverse.each_with_index do |c, i|
      h = {}
      h[:parents] = c.parents.collect do |p|
        [p.scmid, 0, 0]
      end
      h[:rdmid] = i
      h[:space] = 0
      h[:refs]  = refs_map[c.scmid].join(" ") if refs_map.include? c.scmid
      h[:scmid] = c.scmid
      h[:href]  = href_proc.call(c.scmid)
      commit_hashes << h
      map[c.scmid] = h
    end
    heads.sort! do |a,b|
      a.to_s <=> b.to_s
    end
    j = 0
    heads.each do |h|
      if map.include? h.scmid then
        j = mark_chain(j += 1, map[h.scmid], map)
      end
    end
    # when no head matched anything use first commit
    if j == 0 then
       mark_chain(j += 1, map.values.first, map)
    end
    map
  end

  def mark_chain(mark, commit, map)
    stack = [[mark, commit]]
    markmax = mark
    until stack.empty?
      current = stack.pop
      m, commit = current
      commit[:space] = m  if commit[:space] == 0
      m1 = m - 1
      commit[:parents].each_with_index do |p, i|
        psha = p[0]
        if map.include? psha  and  map[psha][:space] == 0 then
          stack << [m1 += 1, map[psha]] if i == 0
          stack = [[m1 += 1, map[psha]]] + stack if i > 0
        end
      end
      markmax = m1 if markmax < m1
    end
    markmax
  end
end
