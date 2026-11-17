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

require_relative '../../../../test_helper'

class ZipArchiveTest < ActiveSupport::TestCase
  # Uses a server time zone other than UTC so that a local time converted
  # to UTC can be detected
  def setup
    @original_tz = ENV['TZ']
    ENV['TZ'] = 'HST10'
  end

  def teardown
    ENV['TZ'] = @original_tz
  end

  def test_add_file_should_rename_duplicate_names
    entries = write_zip(User.find(2)) do |zip|
      3.times { zip.add_file('foo.txt', Time.now) {|sink| sink << 'foo'} }
    end

    assert_equal ['foo.txt', 'foo(1).txt', 'foo(2).txt'], entries.map(&:name)
  end

  def test_add_file_should_store_modification_time_in_user_time_zone
    user = User.find(2)
    user.pref.update!(:time_zone => 'Tokyo')
    entries = write_zip(user) do |zip|
      zip.add_file('foo.txt', Time.utc(2026, 1, 1, 18, 4, 6)) {|sink| sink << 'foo'}
    end

    assert_equal [2026, 1, 2, 3, 4, 6], dos_time_components(entries.first)
    assert_equal Time.utc(2026, 1, 1, 18, 4, 6), entries.first.extra[:universaltime].mtime.utc
  end

  def test_add_file_should_store_modification_time_in_server_local_time_without_user_time_zone
    user = User.find(2)
    user.pref.update!(:time_zone => '')
    entries = write_zip(user) do |zip|
      zip.add_file('foo.txt', Time.utc(2026, 1, 1, 18, 4, 6)) {|sink| sink << 'foo'}
    end

    # 18:04:06 UTC in the server time zone (HST, UTC-10)
    assert_equal [2026, 1, 1, 8, 4, 6], dos_time_components(entries.first)
    assert_equal Time.utc(2026, 1, 1, 18, 4, 6), entries.first.extra[:universaltime].mtime.utc
  end

  private

  def write_zip(user)
    buffer = StringIO.new(+''.b)
    ZipKit::Streamer.open(buffer) do |streamer|
      yield Redmine::Export::ZipArchive.new(streamer, user)
    end
    Zip::File.open_buffer(buffer.string).entries
  end

  def dos_time_components(entry)
    dos_time = entry.instance_variable_get(:@time)
    [dos_time.year, dos_time.month, dos_time.day, dos_time.hour, dos_time.min, dos_time.sec]
  end
end
