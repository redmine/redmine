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

module AttachmentsHelper

  def container_attachments_edit_path(container)
    object_attachments_edit_path container.class.name.underscore.pluralize, container.id
  end

  def container_attachments_path(container)
    object_attachments_path container.class.name.underscore.pluralize, container.id
  end

  # Displays view/delete links to the attachments of the given object
  # Options:
  #   :author -- author names are not displayed if set to false
  #   :thumbails -- display thumbnails if enabled in settings
  def link_to_attachments(container, options = {})
    options.assert_valid_keys(:author, :thumbnails)

    attachments = if container.attachments.loaded?
      container.attachments
    else
      container.attachments.preload(:author).to_a
    end

    if attachments.any?
      options = {
        :editable => container.attachments_editable?,
        :deletable => container.attachments_deletable?,
        :author => true
      }.merge(options)
      render :partial => 'attachments/links',
        :locals => {
          :container => container,
          :attachments => attachments,
          :options => options,
          :thumbnails => (options[:thumbnails] && Setting.thumbnails_enabled?)
        }
    end
  end

  def render_pagination
    pagination_links_each @paginator do |text, parameters, options|
      if att = @attachments[parameters[:page] - 1]
        link_to text, named_attachment_path(att, att.filename)
      end
    end if @paginator
  end

  def render_api_attachment(attachment, api, options={})
    api.attachment do
      render_api_attachment_attributes(attachment, api)
      options.each { |key, value| eval("api.#{key} value") }
    end
  end

  def render_api_attachment_attributes(attachment, api)
    api.id attachment.id
    api.filename attachment.filename
    api.filesize attachment.filesize
    api.content_type attachment.content_type
    api.description attachment.description
    api.content_url download_named_attachment_url(attachment, attachment.filename)
    if attachment.thumbnailable?
      api.thumbnail_url thumbnail_url(attachment)
    end
    if attachment.author
      api.author(:id => attachment.author.id, :name => attachment.author.name)
    end
    api.created_on attachment.created_on
  end
end
