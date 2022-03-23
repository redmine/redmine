# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

class JournalsController < ApplicationController
  before_action :find_journal, :only => [:edit, :update, :diff]
  before_action :find_issue, :only => [:new]
  before_action :find_optional_project, :only => [:index]
  before_action :authorize, :only => [:new, :edit, :update, :diff]
  accept_atom_auth :index
  accept_api_auth :update
  menu_item :issues

  helper :issues
  helper :custom_fields
  helper :queries
  helper :attachments
  include QueriesHelper

  def index
    retrieve_query
    if @query.valid?
      @journals = @query.journals(:order => "#{Journal.table_name}.created_on DESC",
                                  :limit => 25)
    end
    @title = (@project ? @project.name : Setting.app_title) + ": " + (@query.new_record? ? l(:label_changes_details) : @query.name)
    render :layout => false, :content_type => 'application/atom+xml'
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def diff
    @issue = @journal.issue
    if params[:detail_id].present?
      @detail = @journal.details.find_by_id(params[:detail_id])
    else
      @detail = @journal.details.detect {|d| d.property == 'attr' && d.prop_key == 'description'}
    end
    unless @issue && @detail
      render_404
      return false
    end
    if @detail.property == 'cf'
      unless @detail.custom_field && @detail.custom_field.visible_by?(@issue.project, User.current)
        raise ::Unauthorized
      end
    end
    @diff = Redmine::Helpers::Diff.new(@detail.value, @detail.old_value)
  end

  def new
    @journal = Journal.visible.find(params[:journal_id]) if params[:journal_id]
    if @journal
      user = @journal.user
      text = @journal.notes
      @content = +"#{ll(Setting.default_language, :text_user_wrote_in, {:value => user, :link => "#note-#{params[:journal_indice]}"})}\n> "
    else
      user = @issue.author
      text = @issue.description
      @content = +"#{ll(Setting.default_language, :text_user_wrote, user)}\n> "
    end
    # Replaces pre blocks with [...]
    text = text.to_s.strip.gsub(%r{<pre>(.*?)</pre>}m, '[...]')
    @content << text.gsub(/(\r?\n|\r\n?)/, "\n> ") + "\n\n"
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def edit
    (render_403; return false) unless @journal.editable_by?(User.current)
    respond_to do |format|
      # TODO: implement non-JS journal update
      format.js
    end
  end

  def update
    (render_403; return false) unless @journal.editable_by?(User.current)
    @journal.safe_attributes = params[:journal]
    @journal.save
    @journal.destroy if @journal.details.empty? && @journal.notes.blank?
    call_hook(:controller_journals_edit_post, {:journal => @journal, :params => params})
    respond_to do |format|
      format.html {redirect_to issue_path(@journal.journalized)}
      format.js
      format.api { render_api_ok }
    end
  end

  private

  def find_journal
    @journal = Journal.visible.find(params[:id])
    @project = @journal.journalized.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
