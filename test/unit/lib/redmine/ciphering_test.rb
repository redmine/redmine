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

require File.expand_path('../../../../test_helper', __FILE__)

class Redmine::CipheringTest < ActiveSupport::TestCase

  def test_password_should_be_encrypted
    Redmine::Configuration.with 'database_cipher_key' => 'secret' do
      r = Repository::Subversion.create!(:password => 'foo', :url => 'file:///tmp', :identifier => 'svn')
      assert_equal 'foo', r.password
      assert r.read_attribute(:password).match(/\Aaes-256-cbc:.+\Z/)
    end
  end

  def test_password_should_be_clear_with_blank_key
    Redmine::Configuration.with 'database_cipher_key' => '' do
      r = Repository::Subversion.create!(:password => 'foo', :url => 'file:///tmp', :identifier => 'svn')
      assert_equal 'foo', r.password
      assert_equal 'foo', r.read_attribute(:password)
    end
  end

  def test_password_should_be_clear_with_nil_key
    Redmine::Configuration.with 'database_cipher_key' => nil do
      r = Repository::Subversion.create!(:password => 'foo', :url => 'file:///tmp', :identifier => 'svn')
      assert_equal 'foo', r.password
      assert_equal 'foo', r.read_attribute(:password)
    end
  end

  def test_blank_password_should_be_clear
    Redmine::Configuration.with 'database_cipher_key' => 'secret' do
      r = Repository::Subversion.create!(:password => '', :url => 'file:///tmp', :identifier => 'svn')
      assert_equal '', r.password
      assert_equal '', r.read_attribute(:password)
    end
  end

  def test_unciphered_password_should_be_readable
    Redmine::Configuration.with 'database_cipher_key' => nil do
      r = Repository::Subversion.create!(:password => 'clear', :url => 'file:///tmp', :identifier => 'svn')
    end

    Redmine::Configuration.with 'database_cipher_key' => 'secret' do
      r = Repository.order('id DESC').first
      assert_equal 'clear', r.password
    end
  end
  
  def test_ciphered_password_with_no_cipher_key_configured_should_be_returned_ciphered
    Redmine::Configuration.with 'database_cipher_key' => 'secret' do
      r = Repository::Subversion.create!(:password => 'clear', :url => 'file:///tmp', :identifier => 'svn')
    end

    Redmine::Configuration.with 'database_cipher_key' => '' do
      r = Repository.order('id DESC').first
      # password can not be deciphered
      assert_nothing_raised do
        assert r.password.match(/\Aaes-256-cbc:.+\Z/)
      end
    end
  end

  def test_encrypt_all
    Repository.delete_all
    Redmine::Configuration.with 'database_cipher_key' => nil do
      Repository::Subversion.create!(:password => 'foo', :url => 'file:///tmp', :identifier => 'foo')
      Repository::Subversion.create!(:password => 'bar', :url => 'file:///tmp', :identifier => 'bar')
    end

    Redmine::Configuration.with 'database_cipher_key' => 'secret' do
      assert Repository.encrypt_all(:password)
      r = Repository.order('id DESC').first
      assert_equal 'bar', r.password
      assert r.read_attribute(:password).match(/\Aaes-256-cbc:.+\Z/)
    end
  end

  def test_decrypt_all
    Repository.delete_all
    Redmine::Configuration.with 'database_cipher_key' => 'secret' do
      Repository::Subversion.create!(:password => 'foo', :url => 'file:///tmp', :identifier => 'foo')
      Repository::Subversion.create!(:password => 'bar', :url => 'file:///tmp', :identifier => 'bar')

      assert Repository.decrypt_all(:password)
      r = Repository.order('id DESC').first
      assert_equal 'bar', r.password
      assert_equal 'bar', r.read_attribute(:password)
    end
  end
end
