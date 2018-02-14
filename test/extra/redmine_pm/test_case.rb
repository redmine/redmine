# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

require File.expand_path('../../../test_helper', __FILE__)

module RedminePmTest
  class TestCase < ActiveSupport::TestCase
    attr_reader :command, :response, :status, :username, :password
    
    # Cannot use transactional fixtures here: database
    # will be accessed from Redmine.pm with its own connection
    self.use_transactional_fixtures = false
  
    def test_dummy
    end
  
    protected
  
    def assert_response(expected, msg=nil)
      case expected
      when :success
        assert_equal 0, status,
          (msg || "The command failed (exit: #{status}):\n  #{command}\nOutput was:\n#{formatted_response}")
      when :failure
        assert_not_equal 0, status,
          (msg || "The command succeed (exit: #{status}):\n  #{command}\nOutput was:\n#{formatted_response}")
      else
        assert_equal expected, status, msg
      end
    end
  
    def assert_success(*args)
      execute *args
      assert_response :success
    end
  
    def assert_failure(*args)
      execute *args
      assert_response :failure
    end
    
    def with_credentials(username, password)
      old_username, old_password = @username, @password
      @username, @password = username, password
      yield if block_given?
    ensure
      @username, @password = old_username, old_password
    end
    
    def execute(*args)
      @command = args.join(' ')
      @status = nil
      IO.popen("#{command} 2>&1") do |io|
        io.set_encoding("ASCII-8BIT") if io.respond_to?(:set_encoding)
        @response = io.read
      end
      @status = $?.exitstatus
    end
  
    def formatted_response
      "#{'='*40}\n#{response}#{'='*40}"
    end
  
    def random_filename
      Redmine::Utils.random_hex(16)
    end
  end
end
