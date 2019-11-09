# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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
    module PDF
      module WikiPdfHelper
        # Returns a PDF string of a set of wiki pages
        def wiki_pages_to_pdf(pages, project)
          pdf = Redmine::Export::PDF::ITCPDF.new(current_language)
          pdf.set_title(project.name)
          pdf.alias_nb_pages
          pdf.footer_date = format_date(User.current.today)
          pdf.add_page
          pdf.SetFontStyle('B',11)
          pdf.RDMMultiCell(190,5, project.name)
          pdf.ln
          # Set resize image scale
          pdf.set_image_scale(1.6)
          pdf.SetFontStyle('',9)
          write_page_hierarchy(pdf, pages.group_by(&:parent_id))
          pdf.output
        end

        # Returns a PDF string of a single wiki page
        def wiki_page_to_pdf(page, project)
          pdf = ITCPDF.new(current_language)
          pdf.set_title("#{project} - #{page.title}")
          pdf.alias_nb_pages
          pdf.footer_date = format_date(User.current.today)
          pdf.add_page
          pdf.SetFontStyle('B',11)
          pdf.RDMMultiCell(
                190,5,
                "#{project} - #{page.title} - # #{page.content.version}")
          pdf.ln
          # Set resize image scale
          pdf.set_image_scale(1.6)
          pdf.SetFontStyle('',9)
          write_wiki_page(pdf, page)
          pdf.output
        end

        def write_page_hierarchy(pdf, pages, node=nil, level=0)
          if pages[node]
            pages[node].each do |page|
              unless level == 0 && page == pages[node].first
                pdf.add_page
              end
              pdf.bookmark page.title, level
              write_wiki_page(pdf, page)
              write_page_hierarchy(pdf, pages, page.id, level + 1) if pages[page.id]
            end
          end
        end

        def write_wiki_page(pdf, page)
          text =
            textilizable(
              page.content, :text,
              :only_path => false,
              :edit_section_links => false,
              :headings => false,
              :inline_attachments => false
            )
          pdf.RDMwriteFormattedCell(190,5,'','', text, page.attachments, 0)
          if page.attachments.any?
            pdf.ln(5)
            pdf.SetFontStyle('B',9)
            pdf.RDMCell(190,5, l(:label_attachment_plural), "B")
            pdf.ln
            for attachment in page.attachments
              pdf.SetFontStyle('',8)
              pdf.RDMCell(80,5, attachment.filename)
              pdf.RDMCell(20,5, number_to_human_size(attachment.filesize),0,0,"R")
              pdf.RDMCell(25,5, format_date(attachment.created_on),0,0,"R")
              pdf.RDMCell(65,5, attachment.author.name,0,0,"R")
              pdf.ln
            end
          end
        end
      end
    end
  end
end
