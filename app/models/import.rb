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

require 'csv'

class Import < ActiveRecord::Base
  has_many :items, :class_name => 'ImportItem', :dependent => :delete_all
  belongs_to :user
  serialize :settings

  before_destroy :remove_file

  validates_presence_of :filename, :user_id
  validates_length_of :filename, :maximum => 255

  DATE_FORMATS = [
    '%Y-%m-%d',
    '%d/%m/%Y',
    '%m/%d/%Y',
    '%Y/%m/%d',
    '%d.%m.%Y',
    '%d-%m-%Y'
  ]
  AUTO_MAPPABLE_FIELDS = {}

  def self.menu_item
    nil
  end

  def self.layout
    'base'
  end

  def self.authorized?(user)
    user.admin?
  end

  def initialize(*args)
    super
    self.settings ||= {}
  end

  def file=(arg)
    return unless arg.present? && arg.size > 0

    self.filename = generate_filename
    Redmine::Utils.save_upload(arg, filepath)
  end

  def set_default_settings(options={})
    separator = lu(user, :general_csv_separator)
    encoding = lu(user, :general_csv_encoding)
    if file_exists?
      begin
        content = File.read(filepath, 256)

        separator = [',', ';'].max_by {|sep| content.count(sep)}

        guessed_encoding = Redmine::CodesetUtil.guess_encoding(content)
        encoding =
          (guessed_encoding && (
            Setting::ENCODINGS.detect {|e| e.casecmp?(guessed_encoding)} ||
            Setting::ENCODINGS.detect {|e| Encoding.find(e) == Encoding.find(guessed_encoding)}
          )) || lu(user, :general_csv_encoding)
      rescue => e
      end
    end
    wrapper = '"'

    date_format = lu(user, "date.formats.default", :default => "foo")
    date_format = DATE_FORMATS.first unless DATE_FORMATS.include?(date_format)

    self.settings.merge!(
      'separator' => separator,
      'wrapper' => wrapper,
      'encoding' => encoding,
      'date_format' => date_format,
      'notifications' => '0'
    )

    if options.key?(:project_id) && !options[:project_id].blank?
      # Do not fail if project doesn't exist
      begin
        project = Project.find(options[:project_id])
        self.settings.merge!('mapping' => {'project_id' => project.id})
      rescue; end
    end
  end

  def to_param
    filename
  end

  # Returns the full path of the file to import
  # It is stored in tmp/imports with a random hex as filename
  def filepath
    if filename.present? && /\A[0-9a-f]+\z/.match?(filename)
      File.join(Rails.root, "tmp", "imports", filename)
    else
      nil
    end
  end

  # Returns true if the file to import exists
  def file_exists?
    filepath.present? && File.exist?(filepath)
  end

  # Returns the headers as an array that
  # can be used for select options
  def columns_options(default=nil)
    i = -1
    headers.map {|h| [h, i+=1]}
  end

  # Parses the file to import and updates the total number of items
  def parse_file
    count = 0
    read_items {|row, i| count=i}
    update_attribute :total_items, count
    count
  end

  # Reads the items to import and yields the given block for each item
  def read_items
    i = 0
    headers = true
    read_rows do |row|
      if i == 0 && headers
        headers = false
        next
      end
      i+= 1
      yield row, i if block_given?
    end
  end

  # Returns the count first rows of the file (including headers)
  def first_rows(count=4)
    rows = []
    read_rows do |row|
      rows << row
      break if rows.size >= count
    end
    rows
  end

  # Returns an array of headers
  def headers
    first_rows(1).first || []
  end

  # Returns the mapping options
  def mapping
    settings['mapping'] || {}
  end

  # Adds a callback that will be called after the item at given position is imported
  def add_callback(position, name, *args)
    settings['callbacks'] ||= {}
    settings['callbacks'][position] ||= []
    settings['callbacks'][position] << [name, args]
    save!
  end

  # Executes the callbacks for the given object
  def do_callbacks(position, object)
    if callbacks = (settings['callbacks'] || {}).delete(position)
      callbacks.each do |name, args|
        send "#{name}_callback", object, *args
      end
      save!
    end
  end

  # Imports items and returns the position of the last processed item
  def run(options={})
    max_items = options[:max_items]
    max_time = options[:max_time]
    current = 0
    imported = 0
    resume_after = items.maximum(:position) || 0
    interrupted = false
    started_on = Time.now

    read_items do |row, position|
      if (max_items && imported >= max_items) || (max_time && Time.now >= started_on + max_time)
        interrupted = true
        break
      end
      if position > resume_after
        item = items.build
        item.position = position
        item.unique_id = row_value(row, 'unique_id') if use_unique_id?

        if object = build_object(row, item)
          if object.save
            item.obj_id = object.id
          else
            item.message = object.errors.full_messages.join("\n")
          end
        end

        item.save!
        imported += 1

        extend_object(row, item, object) if object.persisted?
        do_callbacks(use_unique_id? ? item.unique_id : item.position, object)
      end
      current = position
    end

    if imported == 0 || interrupted == false
      if total_items.nil?
        update_attribute :total_items, current
      end
      update_attribute :finished, true
      remove_file
    end

    current
  end

  def unsaved_items
    items.where(:obj_id => nil)
  end

  def saved_items
    items.where("obj_id IS NOT NULL")
  end

  private

  def read_rows
    return unless file_exists?

    csv_options = {:headers => false}
    csv_options[:encoding] = settings['encoding'].to_s.presence || 'UTF-8'
    csv_options[:encoding] = 'bom|UTF-8' if csv_options[:encoding] == 'UTF-8'
    separator = settings['separator'].to_s
    csv_options[:col_sep] = separator if separator.size == 1
    wrapper = settings['wrapper'].to_s
    csv_options[:quote_char] = wrapper if wrapper.size == 1

    CSV.foreach(filepath, **csv_options) do |row|
      yield row if block_given?
    end
  end

  def row_value(row, key)
    if index = mapping[key].presence
      row[index.to_i].presence
    end
  end

  def row_date(row, key)
    if s = row_value(row, key)
      format = settings['date_format']
      format = DATE_FORMATS.first unless DATE_FORMATS.include?(format)
      Date.strptime(s, format) rescue s
    end
  end

  # Builds a record for the given row and returns it
  # To be implemented by subclasses
  def build_object(row, item)
  end

  # Extends object with properties, that may only be handled after it's been
  # persisted.
  def extend_object(row, item, object)
  end

  # Generates a filename used to store the import file
  def generate_filename
    Redmine::Utils.random_hex(16)
  end

  # Deletes the import file
  def remove_file
    if file_exists?
      begin
        File.delete filepath
      rescue => e
        logger.error "Unable to delete file #{filepath}: #{e.message}" if logger
      end
    end
  end

  # Returns true if value is a string that represents a true value
  def yes?(value)
    value == lu(user, :general_text_yes) || value == '1'
  end

  def use_unique_id?
    mapping['unique_id'].present?
  end
end
