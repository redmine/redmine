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

require File.expand_path('../../../../../../test_helper', __FILE__)

class Redmine::WikiFormatting::CommonMark::ApplicationHelperTest < Redmine::HelperTest
  if Object.const_defined?(:CommonMarker)

    include ERB::Util
    include Rails.application.routes.url_helpers

    fixtures :projects, :enabled_modules,
             :users, :email_addresses,
             :members, :member_roles, :roles,
             :repositories, :changesets,
             :projects_trackers,
             :trackers, :issue_statuses, :issues, :versions, :documents, :journals,
             :wikis, :wiki_pages, :wiki_contents,
             :boards, :messages, :news,
             :attachments, :enumerations,
             :custom_values, :custom_fields, :custom_fields_projects

    def setup
      super
      set_tmp_attachments_directory
    end

    def test_attached_images_with_markdown_and_non_ascii_filename
      to_test = {
        'CAFÉ.JPG' => 'CAF%C3%89.JPG',
        'crème.jpg' => 'cr%C3%A8me.jpg',
      }
      with_settings :text_formatting => 'common_mark' do
        to_test.each do |filename, result|
          attachment = Attachment.generate!(:filename => filename)
          assert_include %(<img src="/attachments/download/#{attachment.id}/#{result}" alt="" loading="lazy">), textilizable("![](#{filename})", :attachments => [attachment])
        end
      end
    end

    def test_toc_with_markdown_formatting_should_be_parsed
      with_settings :text_formatting => 'common_mark' do
        assert_select_in textilizable("{{toc}}\n\n# Heading"), 'ul.toc li', :text => 'Heading'
        assert_select_in textilizable("{{<toc}}\n\n# Heading"), 'ul.toc.left li', :text => 'Heading'
        assert_select_in textilizable("{{>toc}}\n\n# Heading"), 'ul.toc.right li', :text => 'Heading'
      end
    end

  end
end
