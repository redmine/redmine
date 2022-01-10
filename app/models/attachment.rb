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

require "digest"
require "fileutils"
require "zip"

class Attachment < ActiveRecord::Base
  include Redmine::SafeAttributes
  belongs_to :container, :polymorphic => true
  belongs_to :author, :class_name => "User"

  validates_presence_of :filename, :author
  validates_length_of :filename, :maximum => 255
  validates_length_of :disk_filename, :maximum => 255
  validates_length_of :description, :maximum => 255
  validate :validate_max_file_size
  validate :validate_file_extension, :if => :filename_changed?

  acts_as_event(
    :title => :filename,
    :url =>
      Proc.new do |o|
        {:controller => 'attachments', :action => 'show',
         :id => o.id, :filename => o.filename}
      end
  )
  acts_as_activity_provider(
    :type => 'files',
    :permission => :view_files,
    :author_key => :author_id,
    :scope =>
      proc do
        select("#{Attachment.table_name}.*").
          joins(
            "LEFT JOIN #{Version.table_name} " \
              "ON #{Attachment.table_name}.container_type='Version' " \
              "AND #{Version.table_name}.id = #{Attachment.table_name}.container_id " \
              "LEFT JOIN #{Project.table_name} " \
              "ON #{Version.table_name}.project_id = #{Project.table_name}.id " \
              "OR ( #{Attachment.table_name}.container_type='Project' " \
              "AND #{Attachment.table_name}.container_id = #{Project.table_name}.id )"
          )
      end
  )
  acts_as_activity_provider(
    :type => 'documents',
    :permission => :view_documents,
    :author_key => :author_id,
    :scope =>
      proc do
        select("#{Attachment.table_name}.*").
          joins(
            "LEFT JOIN #{Document.table_name} " \
            "ON #{Attachment.table_name}.container_type='Document' " \
            "AND #{Document.table_name}.id = #{Attachment.table_name}.container_id " \
            "LEFT JOIN #{Project.table_name} " \
            "ON #{Document.table_name}.project_id = #{Project.table_name}.id"
          )
      end
  )

  cattr_accessor :storage_path
  @@storage_path = Redmine::Configuration['attachments_storage_path'] || File.join(Rails.root, "files")

  cattr_accessor :thumbnails_storage_path
  @@thumbnails_storage_path = File.join(Rails.root, "tmp", "thumbnails")

  before_create :files_to_final_location
  after_rollback :delete_from_disk, :on => :create
  after_commit :delete_from_disk, :on => :destroy
  after_commit :reuse_existing_file_if_possible, :on => :create

  safe_attributes 'filename', 'content_type', 'description'

  # Returns an unsaved copy of the attachment
  def copy(attributes=nil)
    copy = self.class.new
    copy.attributes = self.attributes.dup.except("id", "downloads")
    copy.attributes = attributes if attributes
    copy
  end

  def validate_max_file_size
    if @temp_file && self.filesize > Setting.attachment_max_size.to_i.kilobytes
      errors.add(:base, l(:error_attachment_too_big, :max_size => Setting.attachment_max_size.to_i.kilobytes))
    end
  end

  def validate_file_extension
    extension = File.extname(filename)
    unless self.class.valid_extension?(extension)
      errors.add(:base, l(:error_attachment_extension_not_allowed, :extension => extension))
    end
  end

  def file=(incoming_file)
    unless incoming_file.nil?
      @temp_file = incoming_file
      if @temp_file.respond_to?(:original_filename)
        self.filename = @temp_file.original_filename
        self.filename.force_encoding("UTF-8")
      end
      if @temp_file.respond_to?(:content_type)
        self.content_type = @temp_file.content_type.to_s.chomp
      end
      self.filesize = @temp_file.size
    end
  end

  def file
    nil
  end

  def filename=(arg)
    write_attribute :filename, sanitize_filename(arg.to_s)
    filename
  end

  # Copies the temporary file to its final location
  # and computes its MD5 hash
  def files_to_final_location
    if @temp_file
      self.disk_directory = target_directory
      sha = Digest::SHA256.new
      Attachment.create_diskfile(filename, disk_directory) do |f|
        self.disk_filename = File.basename f.path
        logger.info("Saving attachment '#{self.diskfile}' (#{@temp_file.size} bytes)") if logger
        if @temp_file.respond_to?(:read)
          buffer = ""
          while (buffer = @temp_file.read(8192))
            f.write(buffer)
            sha.update(buffer)
          end
        else
          f.write(@temp_file)
          sha.update(@temp_file)
        end
      end
      self.digest = sha.hexdigest
    end
    @temp_file = nil

    if content_type.blank? && filename.present?
      self.content_type = Redmine::MimeType.of(filename)
    end
    # Don't save the content type if it's longer than the authorized length
    if self.content_type && self.content_type.length > 255
      self.content_type = nil
    end
  end

  # Deletes the file from the file system if it's not referenced by other attachments
  def delete_from_disk
    if Attachment.where("disk_filename = ? AND id <> ?", disk_filename, id).empty?
      delete_from_disk!
    end
  end

  # Returns file's location on disk
  def diskfile
    File.join(self.class.storage_path, disk_directory.to_s, disk_filename.to_s)
  end

  def title
    title = filename.dup
    if description.present?
      title << " (#{description})"
    end
    title
  end

  def increment_download
    increment!(:downloads)
  end

  def project
    container.try(:project)
  end

  def visible?(user=User.current)
    if container_id
      container && container.attachments_visible?(user)
    else
      author == user
    end
  end

  def editable?(user=User.current)
    if container_id
      container && container.attachments_editable?(user)
    else
      author == user
    end
  end

  def deletable?(user=User.current)
    if container_id
      container && container.attachments_deletable?(user)
    else
      author == user
    end
  end

  def image?
    !!(self.filename =~ /\.(bmp|gif|jpg|jpe|jpeg|png)$/i)
  end

  def thumbnailable?
    Redmine::Thumbnail.convert_available? && (
      image? || (is_pdf? && Redmine::Thumbnail.gs_available?)
    )
  end

  # Returns the full path the attachment thumbnail, or nil
  # if the thumbnail cannot be generated.
  def thumbnail(options={})
    if thumbnailable? && readable?
      size = options[:size].to_i
      if size > 0
        # Limit the number of thumbnails per image
        size = (size / 50.0).ceil * 50
        # Maximum thumbnail size
        size = 800 if size > 800
      else
        size = Setting.thumbnails_size.to_i
      end
      size = 100 unless size > 0
      target = thumbnail_path(size)

      begin
        Redmine::Thumbnail.generate(self.diskfile, target, size, is_pdf?)
      rescue => e
        if logger
          logger.error(
            "An error occured while generating thumbnail for #{disk_filename} " \
              "to #{target}\nException was: #{e.message}"
          )
        end
        nil
      end
    end
  end

  # Deletes all thumbnails
  def self.clear_thumbnails
    Dir.glob(File.join(thumbnails_storage_path, "*.thumb")).each do |file|
      File.delete file
    end
  end

  def is_text?
    Redmine::MimeType.is_type?('text', filename) || Redmine::SyntaxHighlighting.filename_supported?(filename)
  end

  def is_markdown?
    Redmine::MimeType.of(filename) == 'text/markdown'
  end

  def is_textile?
    Redmine::MimeType.of(filename) == 'text/x-textile'
  end

  def is_image?
    Redmine::MimeType.is_type?('image', filename)
  end

  def is_diff?
    /\.(patch|diff)$/i.match?(filename)
  end

  def is_pdf?
    Redmine::MimeType.of(filename) == "application/pdf"
  end

  def is_video?
    Redmine::MimeType.is_type?('video', filename)
  end

  def is_audio?
    Redmine::MimeType.is_type?('audio', filename)
  end

  def previewable?
    is_text? || is_image? || is_video? || is_audio?
  end

  # Returns true if the file is readable
  def readable?
    disk_filename.present? && File.readable?(diskfile)
  end

  # Returns the attachment token
  def token
    "#{id}.#{digest}"
  end

  # Finds an attachment that matches the given token and that has no container
  def self.find_by_token(token)
    if token.to_s =~ /^(\d+)\.([0-9a-f]+)$/
      attachment_id, attachment_digest = $1, $2
      attachment = Attachment.find_by(:id => attachment_id, :digest => attachment_digest)
      if attachment && attachment.container.nil?
        attachment
      end
    end
  end

  # Bulk attaches a set of files to an object
  #
  # Returns a Hash of the results:
  # :files => array of the attached files
  # :unsaved => array of the files that could not be attached
  def self.attach_files(obj, attachments)
    result = obj.save_attachments(attachments, User.current)
    obj.attach_saved_attachments
    result
  end

  # Updates the filename and description of a set of attachments
  # with the given hash of attributes. Returns true if all
  # attachments were updated.
  #
  # Example:
  #   Attachment.update_attachments(attachments, {
  #     4 => {:filename => 'foo'},
  #     7 => {:filename => 'bar', :description => 'file description'}
  #   })
  #
  def self.update_attachments(attachments, params)
    params = params.transform_keys {|key| key.to_i}

    saved = true
    transaction do
      attachments.each do |attachment|
        if p = params[attachment.id]
          attachment.filename = p[:filename] if p.key?(:filename)
          attachment.description = p[:description] if p.key?(:description)
          saved &&= attachment.save
        end
      end
      unless saved
        raise ActiveRecord::Rollback
      end
    end
    saved
  end

  def self.latest_attach(attachments, filename)
    return unless filename.valid_encoding?

    attachments.sort_by{|attachment| [attachment.created_on, attachment.id]}.reverse.detect do |att|
      filename.casecmp?(att.filename)
    end
  end

  def self.prune(age=1.day)
    Attachment.where("created_on < ? AND (container_type IS NULL OR container_type = '')", Time.now - age).destroy_all
  end

  def self.archive_attachments(attachments)
    attachments = attachments.select(&:readable?)
    return nil if attachments.blank?

    Zip.unicode_names = true
    archived_file_names = []
    buffer = Zip::OutputStream.write_buffer do |zos|
      attachments.each do |attachment|
        filename = attachment.filename
        # rename the file if a file with the same name already exists
        dup_count = 0
        while archived_file_names.include?(filename)
          dup_count += 1
          extname = File.extname(attachment.filename)
          basename = File.basename(attachment.filename, extname)
          filename = "#{basename}(#{dup_count})#{extname}"
        end
        zos.put_next_entry(filename)
        zos << IO.binread(attachment.diskfile)
        archived_file_names << filename
      end
    end
    buffer.string
  ensure
    buffer&.close
  end

  # Moves an existing attachment to its target directory
  def move_to_target_directory!
    return unless !new_record? & readable?

    src = diskfile
    self.disk_directory = target_directory
    dest = diskfile

    return if src == dest

    if !FileUtils.mkdir_p(File.dirname(dest))
      logger.error "Could not create directory #{File.dirname(dest)}" if logger
      return
    end

    if !FileUtils.mv(src, dest)
      logger.error "Could not move attachment from #{src} to #{dest}" if logger
      return
    end

    update_column :disk_directory, disk_directory
  end

  # Moves existing attachments that are stored at the root of the files
  # directory (ie. created before Redmine 2.3) to their target subdirectories
  def self.move_from_root_to_target_directory
    Attachment.where("disk_directory IS NULL OR disk_directory = ''").find_each do |attachment|
      attachment.move_to_target_directory!
    end
  end

  # Updates digests to SHA256 for all attachments that have a MD5 digest
  # (ie. created before Redmine 3.4)
  def self.update_digests_to_sha256
    Attachment.where("length(digest) < 64").find_each do |attachment|
      attachment.update_digest_to_sha256!
    end
  end

  # Updates attachment digest to SHA256
  def update_digest_to_sha256!
    if readable?
      sha = Digest::SHA256.new
      File.open(diskfile, 'rb') do |f|
        while buffer = f.read(8192)
          sha.update(buffer)
        end
      end
      update_column :digest, sha.hexdigest
    end
  end

  # Returns true if the extension is allowed regarding allowed/denied
  # extensions defined in application settings, otherwise false
  def self.valid_extension?(extension)
    denied, allowed = [:attachment_extensions_denied, :attachment_extensions_allowed].map do |setting|
      Setting.send(setting)
    end
    if denied.present? && extension_in?(extension, denied)
      return false
    end
    if allowed.present? && !extension_in?(extension, allowed)
      return false
    end

    true
  end

  # Returns true if extension belongs to extensions list.
  def self.extension_in?(extension, extensions)
    extension = extension.downcase.sub(/\A\.+/, '')

    unless extensions.is_a?(Array)
      extensions = extensions.to_s.split(",").map(&:strip)
    end
    extensions = extensions.map {|s| s.downcase.sub(/\A\.+/, '')}.reject(&:blank?)
    extensions.include?(extension)
  end

  # Returns true if attachment's extension belongs to extensions list.
  def extension_in?(extensions)
    self.class.extension_in?(File.extname(filename), extensions)
  end

  # returns either MD5 or SHA256 depending on the way self.digest was computed
  def digest_type
    digest.size < 64 ? "MD5" : "SHA256" if digest.present?
  end

  private

  def reuse_existing_file_if_possible
    original_diskfile = diskfile
    original_filename = disk_filename
    reused = with_lock do
      if existing = Attachment
                      .where(digest: self.digest, filesize: self.filesize)
                      .where.not(disk_filename: original_filename)
                      .order(:id)
                      .last
        existing.with_lock do
          existing_diskfile = existing.diskfile
          if File.readable?(original_diskfile) &&
            File.readable?(existing_diskfile) &&
            FileUtils.identical?(original_diskfile, existing_diskfile)
            self.update_columns disk_directory: existing.disk_directory,
                                disk_filename: existing.disk_filename
          end
        end
      end
    end
    if reused && Attachment.where(disk_filename: original_filename).none?
      File.delete(original_diskfile)
    end
  rescue ActiveRecord::StatementInvalid, ActiveRecord::RecordNotFound
    # Catch and ignore lock errors. It is not critical if deduplication does
    # not happen, therefore we do not retry.
    # with_lock throws ActiveRecord::RecordNotFound if the record isnt there
    # anymore, thats why this is caught and ignored as well.
  end

  # Physically deletes the file from the file system
  def delete_from_disk!
    if disk_filename.present? && File.exist?(diskfile)
      File.delete(diskfile)
    end
    Dir[thumbnail_path("*")].each do |thumb|
      File.delete(thumb)
    end
  end

  def thumbnail_path(size)
    File.join(self.class.thumbnails_storage_path,
              "#{digest}_#{filesize}_#{size}.thumb")
  end

  def sanitize_filename(value)
    # get only the filename, not the whole path
    just_filename = value.gsub(/\A.*(\\|\/)/m, '')

    # Finally, replace invalid characters with underscore
    just_filename.gsub(/[\/\?\%\*\:\|\"\'<>\n\r]+/, '_')
  end

  # Returns the subdirectory in which the attachment will be saved
  def target_directory
    time = created_on || DateTime.now
    time.strftime("%Y/%m")
  end

  # Singleton class method is public
  class << self
    # Claims a unique ASCII or hashed filename, yields the open file handle
    def create_diskfile(filename, directory=nil, &block)
      timestamp = DateTime.now.strftime("%y%m%d%H%M%S")
      ascii = ''
      if %r{^[a-zA-Z0-9_\.\-]*$}.match?(filename) && filename.length <= 50
        ascii = filename
      else
        ascii = Digest::MD5.hexdigest(filename)
        # keep the extension if any
        ascii << $1 if filename =~ %r{(\.[a-zA-Z0-9]+)$}
      end

      path = File.join storage_path, directory.to_s
      FileUtils.mkdir_p(path) unless File.directory?(path)
      begin
        name = "#{timestamp}_#{ascii}"
        File.open(
          File.join(path, name),
          flags: File::CREAT | File::EXCL | File::WRONLY,
          binmode: true,
          &block
        )
      rescue Errno::EEXIST
        timestamp.succ!
        retry
      end
    end
  end
end
