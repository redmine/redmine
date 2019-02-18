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

class Setting < ActiveRecord::Base

  DATE_FORMATS = [
        '%Y-%m-%d',
        '%d/%m/%Y',
        '%d.%m.%Y',
        '%d-%m-%Y',
        '%m/%d/%Y',
        '%d %b %Y',
        '%d %B %Y',
        '%b %d, %Y',
        '%B %d, %Y'
    ]

  TIME_FORMATS = [
    '%H:%M',
    '%I:%M %p'
    ]

  ENCODINGS = %w(US-ASCII
                  windows-1250
                  windows-1251
                  windows-1252
                  windows-1253
                  windows-1254
                  windows-1255
                  windows-1256
                  windows-1257
                  windows-1258
                  windows-31j
                  ISO-2022-JP
                  ISO-2022-KR
                  ISO-8859-1
                  ISO-8859-2
                  ISO-8859-3
                  ISO-8859-4
                  ISO-8859-5
                  ISO-8859-6
                  ISO-8859-7
                  ISO-8859-8
                  ISO-8859-9
                  ISO-8859-13
                  ISO-8859-15
                  KOI8-R
                  UTF-8
                  UTF-16
                  UTF-16BE
                  UTF-16LE
                  EUC-JP
                  Shift_JIS
                  CP932
                  GB18030
                  GBK
                  ISCII91
                  EUC-KR
                  Big5
                  Big5-HKSCS
                  TIS-620)

  cattr_accessor :available_settings
  self.available_settings ||= {}

  validates_uniqueness_of :name, :if => Proc.new {|setting| setting.new_record? || setting.name_changed?}
  validates_inclusion_of :name, :in => Proc.new {available_settings.keys}
  validates_numericality_of :value, :only_integer => true, :if => Proc.new { |setting|
    (s = available_settings[setting.name]) && s['format'] == 'int'
  }

  # Hash used to cache setting values
  @cached_settings = {}
  @cached_cleared_on = Time.now

  def value
    v = read_attribute(:value)
    # Unserialize serialized settings
    if available_settings[name]['serialized'] && v.is_a?(String)
      v = YAML::load(v)
      v = force_utf8_strings(v)
    end
    v = v.to_sym if available_settings[name]['format'] == 'symbol' && !v.blank?
    v
  end

  def value=(v)
    v = v.to_yaml if v && available_settings[name] && available_settings[name]['serialized']
    write_attribute(:value, v.to_s)
  end

  # Returns the value of the setting named name
  def self.[](name)
    v = @cached_settings[name]
    v ? v : (@cached_settings[name] = find_or_default(name).value)
  end

  def self.[]=(name, v)
    setting = find_or_default(name)
    setting.value = (v ? v : "")
    @cached_settings[name] = nil
    setting.save
    setting.value
  end

  # Updates multiple settings from params and sends a security notification if needed
  def self.set_all_from_params(settings)
    return nil unless settings.is_a?(Hash)
    settings = settings.dup.symbolize_keys

    errors = validate_all_from_params(settings)
    return errors if errors.present?

    changes = []
    settings.each do |name, value|
      next unless available_settings[name.to_s]
      previous_value = Setting[name]
      set_from_params name, value
      if available_settings[name.to_s]['security_notifications'] && Setting[name] != previous_value
        changes << name
      end
    end
    if changes.any?
      Mailer.deliver_settings_updated(User.current, changes)
    end
    nil
  end

  def self.validate_all_from_params(settings)
    messages = []

    [[:mail_handler_enable_regex_delimiters,         :mail_handler_body_delimiters,    /[\r\n]+/],
     [:mail_handler_enable_regex_excluded_filenames, :mail_handler_excluded_filenames, /\s*,\s*/]
    ].each do |enable_regex, regex_field, delimiter|

      if settings.key?(regex_field) || settings.key?(enable_regex)
        regexp = Setting.send("#{enable_regex}?")
        if settings.key?(enable_regex)
          regexp = settings[enable_regex].to_s != '0'
        end
        if regexp
          settings[regex_field].to_s.split(delimiter).each do |value|
            begin
              Regexp.new(value)
            rescue RegexpError => e
              messages << [regex_field, "#{l('activerecord.errors.messages.not_a_regexp')} (#{e.message})"]
            end
          end
        end
      end
    end

    messages
  end

  # Sets a setting value from params
  def self.set_from_params(name, params)
    params = params.dup
    params.delete_if {|v| v.blank? } if params.is_a?(Array)
    params.symbolize_keys! if params.is_a?(Hash)

    m = "#{name}_from_params"
    if respond_to? m
      self[name.to_sym] = send m, params
    else
      self[name.to_sym] = params
    end
  end

  # Returns a hash suitable for commit_update_keywords setting
  #
  # Example:
  # params = {:keywords => ['fixes', 'closes'], :status_id => ["3", "5"], :done_ratio => ["", "100"]}
  # Setting.commit_update_keywords_from_params(params)
  # # => [{'keywords => 'fixes', 'status_id' => "3"}, {'keywords => 'closes', 'status_id' => "5", 'done_ratio' => "100"}]
  def self.commit_update_keywords_from_params(params)
    s = []
    if params.is_a?(Hash) && params.key?(:keywords) && params.values.all? {|v| v.is_a? Array}
      attributes = params.except(:keywords).keys
      params[:keywords].each_with_index do |keywords, i|
        next if keywords.blank?
        s << attributes.inject({}) {|h, a|
          value = params[a][i].to_s
          h[a.to_s] = value if value.present?
          h
        }.merge('keywords' => keywords)
      end
    end
    s
  end

  # Helper that returns an array based on per_page_options setting
  def self.per_page_options_array
    per_page_options.split(%r{[\s,]}).collect(&:to_i).select {|n| n > 0}.sort
  end

  # Helper that returns a Hash with single update keywords as keys
  def self.commit_update_keywords_array
    a = []
    if commit_update_keywords.is_a?(Array)
      commit_update_keywords.each do |rule|
        next unless rule.is_a?(Hash)
        rule = rule.dup
        rule.delete_if {|k, v| v.blank?}
        keywords = rule['keywords'].to_s.downcase.split(",").map(&:strip).reject(&:blank?)
        next if keywords.empty?
        a << rule.merge('keywords' => keywords)
      end
    end
    a
  end

  def self.openid?
    Object.const_defined?(:OpenID) && self[:openid].to_i > 0
  end

  # Checks if settings have changed since the values were read
  # and clears the cache hash if it's the case
  # Called once per request
  def self.check_cache
    settings_updated_on = Setting.maximum(:updated_on)
    if settings_updated_on && @cached_cleared_on <= settings_updated_on
      clear_cache
    end
  end

  # Clears the settings cache
  def self.clear_cache
    @cached_settings.clear
    @cached_cleared_on = Time.now
    logger.info "Settings cache cleared." if logger
  end

  def self.define_plugin_setting(plugin)
    if plugin.settings
      name = "plugin_#{plugin.id}"
      define_setting name, {'default' => plugin.settings[:default], 'serialized' => true}
    end
  end

  # Defines getter and setter for each setting
  # Then setting values can be read using: Setting.some_setting_name
  # or set using Setting.some_setting_name = "some value"
  def self.define_setting(name, options={})
    available_settings[name.to_s] = options

    src = <<-END_SRC
    def self.#{name}
      self[:#{name}]
    end

    def self.#{name}?
      self[:#{name}].to_i > 0
    end

    def self.#{name}=(value)
      self[:#{name}] = value
    end
END_SRC
    class_eval src, __FILE__, __LINE__
  end

  def self.load_available_settings
    YAML::load(File.open("#{Rails.root}/config/settings.yml")).each do |name, options|
      define_setting name, options
    end
  end

  def self.load_plugin_settings
    Redmine::Plugin.all.each do |plugin|
      define_plugin_setting(plugin)
    end
  end

  load_available_settings
  load_plugin_settings

private

  def force_utf8_strings(arg)
    if arg.is_a?(String)
      arg.dup.force_encoding('UTF-8')
    elsif arg.is_a?(Array)
      arg.map do |a|
        force_utf8_strings(a)
      end
    elsif arg.is_a?(Hash)
      arg = arg.dup
      arg.each do |k,v|
        arg[k] = force_utf8_strings(v)
      end
      arg
    else
      arg
    end
  end

  # Returns the Setting instance for the setting named name
  # (record found in database or new record with default value)
  def self.find_or_default(name)
    name = name.to_s
    raise "There's no setting named #{name}" unless available_settings.has_key?(name)
    setting = where(:name => name).order(:id => :desc).first
    unless setting
      setting = new
      setting.name = name
      setting.value = available_settings[name]['default']
    end
    setting
  end
end
