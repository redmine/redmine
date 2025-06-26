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

require 'redmine'

module Redmine
  module I18n
    def self.included(base)
      base.extend Redmine::I18n
    end

    def l(*args)
      case args.size
      when 1
        ::I18n.t(*args)
      when 2
        if args.last.is_a?(Hash)
          ::I18n.t(*args.first, **args.last)
        elsif args.last.is_a?(String)
          ::I18n.t(args.first, :value => args.last)
        else
          ::I18n.t(args.first, :count => args.last)
        end
      else
        raise "Translation string with multiple values: #{args.first}"
      end
    end

    def l_or_humanize(s, options={})
      k = "#{options[:prefix]}#{s}".to_sym
      ::I18n.t(k, :default => s.to_s.humanize)
    end

    def l_hours(hours)
      hours = hours.to_f
      l((hours < 2.0 ? :label_f_hour : :label_f_hour_plural), :value => format_hours(hours))
    end

    def l_hours_short(hours)
      l(:label_f_hour_short, :value => format_hours(hours.to_f))
    end

    def ll(lang, str, arg=nil)
      options = arg.is_a?(Hash) ? arg : {:value => arg}
      locale = lang.to_s.gsub(%r{(.+)\-(.+)$}) {"#{$1}-#{$2.upcase}"}
      ::I18n.t(str.to_s, **options, locale: locale)
    end

    # Localizes the given args with user's language
    def lu(user, *args)
      lang = user.try(:language).presence || Setting.default_language
      ll(lang, *args)
    end

    def format_date(date)
      return nil unless date

      options = {}
      options[:format] = Setting.date_format unless Setting.date_format.blank?
      ::I18n.l(date.to_date, **options)
    end

    def format_time(time, include_date=true, user=nil)
      return nil unless time

      user ||= User.current
      options = {}
      options[:format] = (Setting.time_format.blank? ? :time : Setting.time_format)
      time = time.to_time if time.is_a?(String)
      local = user.convert_time_to_user_timezone(time)
      (include_date ? "#{format_date(local)} " : "") + ::I18n.l(local, **options)
    end

    def format_hours(hours)
      return "" if hours.blank?

      if Setting.timespan_format == 'minutes'
        h = hours.floor
        m = ((hours - h) * 60).round
        "%d:%02d" % [h, m]
      else
        "%.2f" % hours.to_f
      end
    end

    def day_name(day)
      ::I18n.t('date.day_names')[day % 7]
    end

    def day_letter(day)
      ::I18n.t('date.abbr_day_names')[day % 7].first
    end

    def month_name(month)
      ::I18n.t('date.month_names')[month]
    end

    def valid_languages
      ::I18n.available_locales
    end

    # Returns an array of languages names and code sorted by names, example:
    # [["Deutsch", "de"], ["English", "en"] ...]
    #
    # The result is cached to prevent from loading all translations files
    # unless :cache => false option is given
    def languages_options(options={})
      options =
        if options[:cache] == false
          available_locales = ::I18n.backend.available_locales
          valid_languages.
            select {|locale| available_locales.include?(locale)}.
            map {|lang| [ll(lang.to_s, :general_lang_name), lang.to_s]}.
            sort_by(&:first)
        else
          ActionController::Base.cache_store.fetch "i18n/languages_options/#{Redmine::VERSION}" do
            languages_options :cache => false
          end
        end
      options.map {|name, lang| [name.force_encoding("UTF-8"), lang.force_encoding("UTF-8")]}
    end

    def find_language(lang)
      @@languages_lookup ||=
        valid_languages.inject({}) do |k, v|
          k[v.to_s.downcase] = v
          k
        end
      @@languages_lookup[lang.to_s.downcase]
    end

    def set_language_if_valid(lang)
      if l = find_language(lang)
        ::I18n.locale = l
      end
    end

    def current_language
      ::I18n.locale
    end

    # Custom backend based on I18n::Backend::Simple with the following changes:
    # * available_locales are determined by looking at translation file names
    class Backend < ::I18n::Backend::Simple
      module Implementation
        # Get available locales from the translations filenames
        def available_locales
          @available_locales ||= ::I18n.load_path.map {|path| File.basename(path, '.*')}.uniq.sort.map(&:to_sym)
        end
      end

      # Adds custom pluralization rules
      include ::I18n::Backend::Pluralization
      # Adds fallback to default locale for untranslated strings
      include ::I18n::Backend::Fallbacks
    end
  end
end
