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

require File.expand_path('../../test_helper', __FILE__)

class DocumentTest < ActiveSupport::TestCase
  fixtures :projects, :enumerations, :documents, :attachments,
           :enabled_modules,
           :users, :email_addresses, :members, :member_roles, :roles,
           :groups_users

  def setup
    User.current = nil
  end

  def test_create
    doc = Document.new(:project => Project.find(1), :title => 'New document', :category => Enumeration.find_by_name('User documentation'))
    assert doc.save
  end

  def test_create_with_long_title
    title = 'x'*255
    doc = Document.new(:project => Project.find(1), :title => title, :category => DocumentCategory.first)
    assert_save doc
    assert_equal title, doc.reload.title
  end

  def test_create_should_send_email_notification
    ActionMailer::Base.deliveries.clear
    with_settings :notified_events => %w(document_added) do
      doc = Document.new(:project => Project.find(1), :title => 'New document', :category => Enumeration.find_by_name('User documentation'))
      assert doc.save
    end
    assert_equal 2, ActionMailer::Base.deliveries.size
  end

  def test_create_with_default_category
    # Sets a default category
    e = Enumeration.find_by_name('Technical documentation')
    e.update(:is_default => true)

    doc = Document.new(:project => Project.find(1), :title => 'New document')
    assert_equal e, doc.category
    assert doc.save
  end

  def test_updated_on_with_attachments
    d = Document.find(1)
    assert d.attachments.any?
    assert_equal d.attachments.map(&:created_on).max, d.updated_on
  end

  def test_updated_on_without_attachments
    d = Document.find(2)
    assert d.attachments.empty?
    assert_equal d.created_on, d.updated_on
  end
end
