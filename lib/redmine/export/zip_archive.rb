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

module Redmine
  module Export
    class ZipArchive
      def initialize(streamer, user)
        @streamer = streamer
        @user = user
        @entry_names = Set.new
      end

      def add_file(name, modification_time, &)
        entry_name = unique_entry_name(name)
        @entry_names << entry_name
        @streamer.write_file(entry_name, :modification_time => zip_time(modification_time), &)
      end

      private

      def unique_entry_name(name)
        entry_name = name
        extname = File.extname(name)
        basename = File.basename(name, extname)
        dup_count = 0
        while @entry_names.include?(entry_name)
          dup_count += 1
          entry_name = "#{basename}(#{dup_count})#{extname}"
        end
        entry_name
      end

      # DateTime is used because zip_kit calls #utc on the given time,
      # which converts a Time object in place.
      def zip_time(time)
        @user.convert_time_to_user_timezone(time).to_datetime
      end
    end
  end
end
