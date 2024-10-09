# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
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

class MessagesController < ApplicationController
  menu_item :boards
  default_search_scope :messages
  before_action :find_board, :only => [:new, :preview]
  before_action :find_attachments, :only => [:preview]
  before_action :find_message, :except => [:new, :preview]
  before_action :authorize, :except => [:preview, :edit, :destroy]

  helper :boards
  helper :watchers
  helper :attachments
  include AttachmentsHelper
  include Redmine::QuoteReply::Builder

  REPLIES_PER_PAGE = 25 unless const_defined?(:REPLIES_PER_PAGE)

  # Show a topic and its replies
  def show
    page = params[:page]
    # Find the page of the requested reply
    if params[:r] && page.nil?
      offset = @topic.children.where("#{Message.table_name}.id < ?", params[:r].to_i).count
      page = 1 + offset / REPLIES_PER_PAGE
    end

    @reply_count = @topic.children.count
    @reply_pages = Paginator.new @reply_count, REPLIES_PER_PAGE, page
    @replies =  @topic.children.
      includes(:author, :attachments, {:board => :project}).
      reorder("#{Message.table_name}.created_on ASC, #{Message.table_name}.id ASC").
      limit(@reply_pages.per_page).
      offset(@reply_pages.offset).
      to_a

    @reply = Message.new(:subject => "RE: #{@message.subject}")
    render :action => "show", :layout => false if request.xhr?
  end

  # Create a new topic
  def new
    @message = Message.new
    @message.author = User.current
    @message.board = @board
    @message.safe_attributes = params[:message]
    if request.post?
      @message.save_attachments(params[:attachments])
      if @message.save
        call_hook(:controller_messages_new_after_save, {:params => params, :message => @message})
        render_attachment_warning_if_needed(@message)
        flash[:notice] = l(:notice_successful_create)
        redirect_to board_message_path(@board, @message)
      end
    end
  end

  # Reply to a topic
  def reply
    @reply = Message.new
    @reply.author = User.current
    @reply.board = @board
    @reply.safe_attributes = params[:reply]
    @reply.save_attachments(params[:attachments])
    @topic.children << @reply
    unless @reply.new_record?
      call_hook(:controller_messages_reply_after_save, {:params => params, :message => @reply})
      render_attachment_warning_if_needed(@reply)
    end
    flash[:notice] = l(:notice_successful_update)
    redirect_to board_message_path(@board, @topic, :r => @reply)
  end

  # Edit a message
  def edit
    (render_403; return false) unless @message.editable_by?(User.current)
    @message.safe_attributes = params[:message]
    if request.post?
      @message.save_attachments(params[:attachments])
      if @message.save
        render_attachment_warning_if_needed(@message)
        flash[:notice] = l(:notice_successful_update)
        @message.reload
        redirect_to board_message_path(@message.board, @message.root, :r => (@message.parent_id && @message.id))
      end
    end
  end

  # Delete a messages
  def destroy
    (render_403; return false) unless @message.destroyable_by?(User.current)
    r = @message.to_param
    @message.destroy
    flash[:notice] = l(:notice_successful_delete)
    if @message.parent
      redirect_to board_message_path(@board, @message.parent, :r => r)
    else
      redirect_to project_board_path(@project, @board)
    end
  end

  def quote
    @subject = @message.subject
    @subject = "RE: #{@subject}" unless @subject.starts_with?('RE:')

    @content = if @message.root == @message
                 quote_root_message(@message, partial_quote: params[:quote])
               else
                 quote_message(@message, partial_quote: params[:quote])
               end

    respond_to do |format|
      format.html { render_404 }
      format.js
    end
  end

  def preview
    message = @board.messages.find_by_id(params[:id])
    @text = params[:text] ? params[:text] : nil
    @previewed = message
    render :partial => 'common/preview'
  end

  private

  def find_message
    return unless find_board

    @message = @board.messages.includes(:parent).find(params[:id])
    @topic = @message.root
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_board
    @board = Board.includes(:project).find(params[:board_id])
    @project = @board.project
  rescue ActiveRecord::RecordNotFound
    render_404
    nil
  end
end
