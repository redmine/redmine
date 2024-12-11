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

require_relative '../../../../../test_helper'

class Redmine::WikiFormatting::CommonMark::ApplicationHelperTest < Redmine::HelperTest
  if Object.const_defined?(:CommonMarker)

    include ERB::Util

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

    def test_attached_image_alt_attribute_with_madkrown
      attachments = Attachment.all
      with_settings text_formatting: 'common_mark' do
        # When alt text is set
        assert_match %r[<img src=".+?" alt="alt text" loading=".+?">],
          textilizable('![alt text](logo.gif)', attachments: attachments)

        # When alt text is not set
        assert_match %r[<img src=".+?" title="This is a logo" alt="This is a logo" loading=".+?">],
          textilizable('![](logo.gif)', attachments: attachments)

        # When alt text is not set and the attachment has no description
        assert_match %r[<img src=".+?" alt="" loading=".+?">],
          textilizable('![](testfile.PNG)', attachments: attachments)

        # When no matching attachments are found
        assert_match %r[<img src=".+?" alt="">],
          textilizable('![](no-match.jpg)', attachments: attachments)
        assert_match %r[<img src=".+?" alt="alt text">],
          textilizable('![alt text](no-match.jpg)', attachments: attachments)

        # When no attachment is registered
        assert_match %r[<img src=".+?" alt="">],
          textilizable('![](logo.gif)', attachments: [])
        assert_match %r[<img src=".+?" alt="alt text">],
          textilizable('![alt text](logo.gif)', attachments: [])
      end
    end
  end
end
