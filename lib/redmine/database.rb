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

module Redmine
  # Helper module to get information about the Redmine database
  module Database
    class << self
      # Returns true if the database is SQLite
      def sqlite?
        ActiveRecord::Base.connection.adapter_name =~ /sqlite/i
      end

      # Returns true if the database is PostgreSQL
      def postgresql?
        /postgresql/i.match?(ActiveRecord::Base.connection.adapter_name)
      end

      # Returns the PostgreSQL version or nil if another DBMS is used
      def postgresql_version
        postgresql? ? ActiveRecord::Base.connection.send(:postgresql_version) : nil
      end

      # Returns true if the database is a PostgreSQL >=9.0 database with the unaccent extension installed
      def postgresql_unaccent?
        if postgresql?
          return @postgresql_unaccent unless @postgresql_unaccent.nil?

          begin
            sql =
              "SELECT name FROM pg_available_extensions " \
                "WHERE installed_version IS NOT NULL and name = 'unaccent'"
            @postgresql_unaccent =
              postgresql_version >= 90000 &&
                ActiveRecord::Base.connection.select_value(sql).present?
          rescue
            false
          end
        else
          false
        end
      end

      # Returns true if the database is MySQL
      def mysql?
        /mysql/i.match?(ActiveRecord::Base.connection.adapter_name)
      end

      # Returns a SQL statement for case/accent (if possible) insensitive match
      def like(left, right, options={})
        neg = (options[:match] == false ? 'NOT ' : '')

        if postgresql?
          if postgresql_unaccent?
            "unaccent(#{left}) #{neg}ILIKE unaccent(#{right})"
          else
            "#{left} #{neg}ILIKE #{right}"
          end
        elsif mysql?
          "#{left} #{neg}LIKE #{right}"
        else
          "#{left} #{neg}LIKE #{right} ESCAPE '\\'"
        end
      end

      # Returns a SQL statement to cast a timestamp column to a date given a time zone
      # Returns nil if not implemented for the current database
      def timestamp_to_date(column, time_zone)
        if postgresql?
          if time_zone
            identifier = ActiveSupport::TimeZone.find_tzinfo(time_zone.name).identifier
            "(#{column}::timestamptz AT TIME ZONE '#{identifier}')::date"
          else
            "#{column}::date"
          end
        elsif mysql?
          if time_zone
            user_identifier = ActiveSupport::TimeZone.find_tzinfo(time_zone.name).identifier
            local_identifier = ActiveSupport::TimeZone.find_tzinfo(Time.zone.name).identifier
            "DATE(CONVERT_TZ(#{column},'#{local_identifier}', '#{user_identifier}'))"
          else
            "DATE(#{column})"
          end
        end
      end

      # Resets database information
      def reset
        @postgresql_unaccent = nil
      end
    end
  end
end
