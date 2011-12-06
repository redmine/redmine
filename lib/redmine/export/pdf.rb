# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
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

require 'iconv'
require 'fpdf/chinese'
require 'fpdf/japanese'
require 'fpdf/korean'
require 'core/rmagick'

module Redmine
  module Export
    module PDF
      include ActionView::Helpers::TextHelper
      include ActionView::Helpers::NumberHelper
      include IssuesHelper

      class ITCPDF < TCPDF
        include Redmine::I18n
        attr_accessor :footer_date

        def initialize(lang)
          @@k_path_cache = Rails.root.join('tmp', 'pdf')
          FileUtils.mkdir_p @@k_path_cache unless File::exist?(@@k_path_cache)
          set_language_if_valid lang
          pdf_encoding = l(:general_pdf_encoding).upcase
          super('P', 'mm', 'A4', (pdf_encoding == 'UTF-8'), pdf_encoding)
          case current_language.to_s.downcase
          when 'vi'
            @font_for_content = 'DejaVuSans'
            @font_for_footer  = 'DejaVuSans'
          else
            case pdf_encoding
            when 'UTF-8'
              @font_for_content = 'FreeSans'
              @font_for_footer  = 'FreeSans'
            when 'CP949'
              extend(PDF_Korean)
              AddUHCFont()
              @font_for_content = 'UHC'
              @font_for_footer  = 'UHC'
            when 'CP932', 'SJIS', 'SHIFT_JIS'
              extend(PDF_Japanese)
              AddSJISFont()
              @font_for_content = 'SJIS'
              @font_for_footer  = 'SJIS'
            when 'GB18030'
              extend(PDF_Chinese)
              AddGBFont()
              @font_for_content = 'GB'
              @font_for_footer  = 'GB'
            when 'BIG5'
              extend(PDF_Chinese)
              AddBig5Font()
              @font_for_content = 'Big5'
              @font_for_footer  = 'Big5'
            else
              @font_for_content = 'Arial'
              @font_for_footer  = 'Helvetica'
            end
          end
          SetCreator(Redmine::Info.app_name)
          SetFont(@font_for_content)
        end

        def SetFontStyle(style, size)
          SetFont(@font_for_content, style, size)
        end

        def SetTitle(txt)
          txt = begin
            utf16txt = Iconv.conv('UTF-16BE', 'UTF-8', txt)
            hextxt = "<FEFF"  # FEFF is BOM
            hextxt << utf16txt.unpack("C*").map {|x| sprintf("%02X",x) }.join
            hextxt << ">"
          rescue
            txt
          end || ''
          super(txt)
        end

        def textstring(s)
          # Format a text string
          if s =~ /^</  # This means the string is hex-dumped.
            return s
          else
            return '('+escape(s)+')'
          end
        end

        def fix_text_encoding(txt)
          RDMPdfEncoding::rdm_from_utf8(txt, l(:general_pdf_encoding))
        end

        def RDMCell(w ,h=0, txt='', border=0, ln=0, align='', fill=0, link='')
          Cell(w, h, fix_text_encoding(txt), border, ln, align, fill, link)
        end

        def RDMMultiCell(w, h=0, txt='', border=0, align='', fill=0, ln=1)
          MultiCell(w, h, fix_text_encoding(txt), border, align, fill, ln)
        end

        def RDMwriteHTMLCell(w, h, x, y, txt='', attachments=[], border=0, ln=1, fill=0)
          @attachments = attachments
          writeHTMLCell(w, h, x, y,
            fix_text_encoding(
              Redmine::WikiFormatting.to_html(Setting.text_formatting, txt)),
            border, ln, fill)
        end

        def getImageFilename(attrname)
          # attrname: general_pdf_encoding string file/uri name
          atta = RDMPdfEncoding.attach(@attachments, attrname, l(:general_pdf_encoding))
          if atta
            return atta.diskfile
          else
            return nil
          end
        end

        def Footer
          SetFont(@font_for_footer, 'I', 8)
          SetY(-15)
          SetX(15)
          RDMCell(0, 5, @footer_date, 0, 0, 'L')
          SetY(-15)
          SetX(-30)
          RDMCell(0, 5, PageNo().to_s + '/{nb}', 0, 0, 'C')
        end
      end

      # Returns a PDF string of a list of issues
      def issues_to_pdf(issues, project, query)
        pdf = ITCPDF.new(current_language)
        title = query.new_record? ? l(:label_issue_plural) : query.name
        title = "#{project} - #{title}" if project
        pdf.SetTitle(title)
        pdf.alias_nb_pages
        pdf.footer_date = format_date(Date.today)
        pdf.SetAutoPageBreak(false)
        pdf.AddPage("L")

        # Landscape A4 = 210 x 297 mm
        page_height   = 210
        page_width    = 297
        right_margin  = 10
        bottom_margin = 20
        col_id_width  = 10
        row_height    = 5

        # column widths
        table_width = page_width - right_margin - 10  # fixed left margin
        col_width = []
        unless query.columns.empty?
          col_width = query.columns.collect do |c|
            (c.name == :subject || (c.is_a?(QueryCustomFieldColumn) &&
              ['string', 'text'].include?(c.custom_field.field_format))) ? 4.0 : 1.0
          end
          ratio = (table_width - col_id_width) / col_width.inject(0) {|s,w| s += w}
          col_width = col_width.collect {|w| w * ratio}
        end

        # title
        pdf.SetFontStyle('B',11)
        pdf.RDMCell(190,10, title)
        pdf.Ln

        # headers
        pdf.SetFontStyle('B',8)
        pdf.SetFillColor(230, 230, 230)

        # render it background to find the max height used
        base_x = pdf.GetX
        base_y = pdf.GetY
        max_height = issues_to_pdf_write_cells(pdf, query.columns, col_width, row_height, true)
        pdf.Rect(base_x, base_y, table_width, max_height, 'FD');
        pdf.SetXY(base_x, base_y);

        # write the cells on page
        pdf.RDMCell(col_id_width, row_height, "#", "T", 0, 'C', 1)
        issues_to_pdf_write_cells(pdf, query.columns, col_width, row_height, true)
        issues_to_pdf_draw_borders(pdf, base_x, base_y, base_y + max_height, col_id_width, col_width)
        pdf.SetY(base_y + max_height);

        # rows
        pdf.SetFontStyle('',8)
        pdf.SetFillColor(255, 255, 255)
        previous_group = false
        issue_list(issues) do |issue, level|
          if query.grouped? &&
               (group = query.group_by_column.value(issue)) != previous_group
            pdf.SetFontStyle('B',9)
            pdf.RDMCell(277, row_height,
              (group.blank? ? 'None' : group.to_s) + " (#{query.issue_count_by_group[group]})",
              1, 1, 'L')
            pdf.SetFontStyle('',8)
            previous_group = group
          end
          # fetch all the row values
          col_values = query.columns.collect do |column|
            s = if column.is_a?(QueryCustomFieldColumn)
              cv = issue.custom_values.detect {|v| v.custom_field_id == column.custom_field.id}
              show_value(cv)
            else
              value = issue.send(column.name)
              if column.name == :subject
                value = "  " * level + value
              end
              if value.is_a?(Date)
                format_date(value)
              elsif value.is_a?(Time)
                format_time(value)
              else
                value
              end
            end
            s.to_s
          end

          # render it off-page to find the max height used
          base_x = pdf.GetX
          base_y = pdf.GetY
          pdf.SetY(2 * page_height)
          max_height = issues_to_pdf_write_cells(pdf, col_values, col_width, row_height)
          pdf.SetXY(base_x, base_y)

          # make new page if it doesn't fit on the current one
          space_left = page_height - base_y - bottom_margin
          if max_height > space_left
            pdf.AddPage("L")
            base_x = pdf.GetX
            base_y = pdf.GetY
          end

          # write the cells on page
          pdf.RDMCell(col_id_width, row_height, issue.id.to_s, "T", 0, 'C', 1)
          issues_to_pdf_write_cells(pdf, col_values, col_width, row_height)
          issues_to_pdf_draw_borders(pdf, base_x, base_y, base_y + max_height, col_id_width, col_width)
          pdf.SetY(base_y + max_height);
        end

        if issues.size == Setting.issues_export_limit.to_i
          pdf.SetFontStyle('B',10)
          pdf.RDMCell(0, row_height, '...')
        end
        pdf.Output
      end

      # Renders MultiCells and returns the maximum height used
      def issues_to_pdf_write_cells(pdf, col_values, col_widths,
                                    row_height, head=false)
        base_y = pdf.GetY
        max_height = row_height
        col_values.each_with_index do |column, i|
          col_x = pdf.GetX
          if head == true
            pdf.RDMMultiCell(col_widths[i], row_height, column.caption, "T", 'L', 1)
          else
            pdf.RDMMultiCell(col_widths[i], row_height, column, "T", 'L', 1)
          end
          max_height = (pdf.GetY - base_y) if (pdf.GetY - base_y) > max_height
          pdf.SetXY(col_x + col_widths[i], base_y);
        end
        return max_height
      end

      # Draw lines to close the row (MultiCell border drawing in not uniform)
      def issues_to_pdf_draw_borders(pdf, top_x, top_y, lower_y,
                                     id_width, col_widths)
        col_x = top_x + id_width
        pdf.Line(col_x, top_y, col_x, lower_y)    # id right border
        col_widths.each do |width|
          col_x += width
          pdf.Line(col_x, top_y, col_x, lower_y)  # columns right border
        end
        pdf.Line(top_x, top_y, top_x, lower_y)    # left border
        pdf.Line(top_x, lower_y, col_x, lower_y)  # bottom border
      end

      # Returns a PDF string of a single issue
      def issue_to_pdf(issue)
        pdf = ITCPDF.new(current_language)
        pdf.SetTitle("#{issue.project} - ##{issue.tracker} #{issue.id}")
        pdf.alias_nb_pages
        pdf.footer_date = format_date(Date.today)
        pdf.AddPage
        pdf.SetFontStyle('B',11)
        buf = "#{issue.project} - #{issue.tracker} # #{issue.id}"
        pdf.RDMMultiCell(190, 5, buf)
        pdf.Ln
        pdf.SetFontStyle('',8)
        base_x = pdf.GetX
        i = 1
        issue.ancestors.each do |ancestor|
          pdf.SetX(base_x + i)
          buf = "#{ancestor.tracker} # #{ancestor.id} (#{ancestor.status.to_s}): #{ancestor.subject}"
          pdf.RDMMultiCell(190 - i, 5, buf)
          i += 1 if i < 35
        end
        pdf.Ln

        pdf.SetFontStyle('B',9)
        pdf.RDMCell(35,5, l(:field_status) + ":","LT")
        pdf.SetFontStyle('',9)
        pdf.RDMCell(60,5, issue.status.to_s,"RT")
        pdf.SetFontStyle('B',9)
        pdf.RDMCell(35,5, l(:field_priority) + ":","LT")
        pdf.SetFontStyle('',9)
        pdf.RDMCell(60,5, issue.priority.to_s,"RT")
        pdf.Ln

        pdf.SetFontStyle('B',9)
        pdf.RDMCell(35,5, l(:field_author) + ":","L")
        pdf.SetFontStyle('',9)
        pdf.RDMCell(60,5, issue.author.to_s,"R")
        pdf.SetFontStyle('B',9)
        pdf.RDMCell(35,5, l(:field_category) + ":","L")
        pdf.SetFontStyle('',9)
        pdf.RDMCell(60,5, issue.category.to_s,"R")
        pdf.Ln

        pdf.SetFontStyle('B',9)
        pdf.RDMCell(35,5, l(:field_created_on) + ":","L")
        pdf.SetFontStyle('',9)
        pdf.RDMCell(60,5, format_date(issue.created_on),"R")
        pdf.SetFontStyle('B',9)
        pdf.RDMCell(35,5, l(:field_assigned_to) + ":","L")
        pdf.SetFontStyle('',9)
        pdf.RDMCell(60,5, issue.assigned_to.to_s,"R")
        pdf.Ln

        pdf.SetFontStyle('B',9)
        pdf.RDMCell(35,5, l(:field_updated_on) + ":","LB")
        pdf.SetFontStyle('',9)
        pdf.RDMCell(60,5, format_date(issue.updated_on),"RB")
        pdf.SetFontStyle('B',9)
        pdf.RDMCell(35,5, l(:field_due_date) + ":","LB")
        pdf.SetFontStyle('',9)
        pdf.RDMCell(60,5, format_date(issue.due_date),"RB")
        pdf.Ln

        for custom_value in issue.custom_field_values
          pdf.SetFontStyle('B',9)
          pdf.RDMCell(35,5, custom_value.custom_field.name + ":","L")
          pdf.SetFontStyle('',9)
          pdf.RDMMultiCell(155,5, (show_value custom_value),"R")
        end

        y0 = pdf.GetY

        pdf.SetFontStyle('B',9)
        pdf.RDMCell(35,5, l(:field_subject) + ":","LT")
        pdf.SetFontStyle('',9)
        pdf.RDMMultiCell(155,5, issue.subject,"RT")
        pdf.Line(pdf.GetX, y0, pdf.GetX, pdf.GetY)

        pdf.SetFontStyle('B',9)
        pdf.RDMCell(35+155, 5, l(:field_description), "LRT", 1)
        pdf.SetFontStyle('',9)

        # Set resize image scale
        pdf.SetImageScale(1.6)
        pdf.RDMwriteHTMLCell(35+155, 5, 0, 0,
              issue.description.to_s, issue.attachments, "LRB")

        unless issue.leaf?
          # for CJK
          truncate_length = ( l(:general_pdf_encoding).upcase == "UTF-8" ? 90 : 65 )
  
          pdf.SetFontStyle('B',9)
          pdf.RDMCell(35+155,5, l(:label_subtask_plural) + ":", "LTR")
          pdf.Ln
          issue_list(issue.descendants.sort_by(&:lft)) do |child, level|
            buf = truncate("#{child.tracker} # #{child.id}: #{child.subject}",
                           :length => truncate_length)
            level = 10 if level >= 10
            pdf.SetFontStyle('',8)
            pdf.RDMCell(35+135,5, (level >=1 ? "  " * level : "") + buf, "L")
            pdf.SetFontStyle('B',8)
            pdf.RDMCell(20,5, child.status.to_s, "R")
            pdf.Ln
          end
        end

        relations = issue.relations.select { |r| r.other_issue(issue).visible? }
        unless relations.empty?
          # for CJK
          truncate_length = ( l(:general_pdf_encoding).upcase == "UTF-8" ? 80 : 60 )
  
          pdf.SetFontStyle('B',9)
          pdf.RDMCell(35+155,5, l(:label_related_issues) + ":", "LTR")
          pdf.Ln
          relations.each do |relation|
            buf = ""
            buf += "#{l(relation.label_for(issue))} "
            if relation.delay && relation.delay != 0
              buf += "(#{l('datetime.distance_in_words.x_days', :count => relation.delay)}) "
            end
            if Setting.cross_project_issue_relations?
              buf += "#{relation.other_issue(issue).project} - "
            end
            buf += "#{relation.other_issue(issue).tracker}" +
                   " # #{relation.other_issue(issue).id}: #{relation.other_issue(issue).subject}"
            buf = truncate(buf, :length => truncate_length)
            pdf.SetFontStyle('', 8)
            pdf.RDMCell(35+155-60, 5, buf, "L")
            pdf.SetFontStyle('B',8)
            pdf.RDMCell(20,5, relation.other_issue(issue).status.to_s, "")
            pdf.RDMCell(20,5, format_date(relation.other_issue(issue).start_date), "")
            pdf.RDMCell(20,5, format_date(relation.other_issue(issue).due_date), "R")
            pdf.Ln
          end
        end
        pdf.RDMCell(190,5, "", "T")
        pdf.Ln

        if issue.changesets.any? &&
             User.current.allowed_to?(:view_changesets, issue.project)
          pdf.SetFontStyle('B',9)
          pdf.RDMCell(190,5, l(:label_associated_revisions), "B")
          pdf.Ln
          for changeset in issue.changesets
            pdf.SetFontStyle('B',8)
            csstr  = "#{l(:label_revision)} #{changeset.format_identifier} - "
            csstr += format_time(changeset.committed_on) + " - " + changeset.author.to_s
            pdf.RDMCell(190, 5, csstr)
            pdf.Ln
            unless changeset.comments.blank?
              pdf.SetFontStyle('',8)
              pdf.RDMwriteHTMLCell(190,5,0,0,
                    changeset.comments.to_s, issue.attachments, "")
            end
            pdf.Ln
          end
        end

        pdf.SetFontStyle('B',9)
        pdf.RDMCell(190,5, l(:label_history), "B")
        pdf.Ln
        indice = 0
        for journal in issue.journals.find(
                          :all, :include => [:user, :details],
                          :order => "#{Journal.table_name}.created_on ASC")
          indice = indice + 1
          pdf.SetFontStyle('B',8)
          pdf.RDMCell(190,5,
             "#" + indice.to_s +
             " - " + format_time(journal.created_on) +
             " - " + journal.user.name)
          pdf.Ln
          pdf.SetFontStyle('I',8)
          for detail in journal.details
            pdf.RDMMultiCell(190,5, "- " + show_detail(detail, true))
          end
          if journal.notes?
            pdf.Ln unless journal.details.empty?
            pdf.SetFontStyle('',8)
            pdf.RDMwriteHTMLCell(190,5,0,0,
                  journal.notes.to_s, issue.attachments, "")
          end
          pdf.Ln
        end

        if issue.attachments.any?
          pdf.SetFontStyle('B',9)
          pdf.RDMCell(190,5, l(:label_attachment_plural), "B")
          pdf.Ln
          for attachment in issue.attachments
            pdf.SetFontStyle('',8)
            pdf.RDMCell(80,5, attachment.filename)
            pdf.RDMCell(20,5, number_to_human_size(attachment.filesize),0,0,"R")
            pdf.RDMCell(25,5, format_date(attachment.created_on),0,0,"R")
            pdf.RDMCell(65,5, attachment.author.name,0,0,"R")
            pdf.Ln
          end
        end
        pdf.Output
      end

      # Returns a PDF string of a single wiki page
      def wiki_to_pdf(page, project)
        pdf = ITCPDF.new(current_language)
        pdf.SetTitle("#{project} - #{page.title}")
        pdf.alias_nb_pages
        pdf.footer_date = format_date(Date.today)
        pdf.AddPage
        pdf.SetFontStyle('B',11)
        pdf.RDMMultiCell(190,5,
             "#{project} - #{page.title} - # #{page.content.version}")
        pdf.Ln
        # Set resize image scale
        pdf.SetImageScale(1.6)
        pdf.SetFontStyle('',9)
        pdf.RDMwriteHTMLCell(190,5,0,0,
              page.content.text.to_s, page.attachments, "TLRB")
        if page.attachments.any?
          pdf.Ln
          pdf.SetFontStyle('B',9)
          pdf.RDMCell(190,5, l(:label_attachment_plural), "B")
          pdf.Ln
          for attachment in page.attachments
            pdf.SetFontStyle('',8)
            pdf.RDMCell(80,5, attachment.filename)
            pdf.RDMCell(20,5, number_to_human_size(attachment.filesize),0,0,"R")
            pdf.RDMCell(25,5, format_date(attachment.created_on),0,0,"R")
            pdf.RDMCell(65,5, attachment.author.name,0,0,"R")
            pdf.Ln
          end
        end
        pdf.Output
      end

      class RDMPdfEncoding
        def self.rdm_from_utf8(txt, encoding)
          txt ||= ''
          txt = Redmine::CodesetUtil.from_utf8(txt, encoding)
          if txt.respond_to?(:force_encoding)
            txt.force_encoding('ASCII-8BIT')
          end
          txt
        end

        def self.attach(attachments, filename, encoding)
          filename_utf8 = Redmine::CodesetUtil.to_utf8(filename, encoding)
          atta = nil
          if filename_utf8 =~ /^[^\/"]+\.(gif|jpg|jpe|jpeg|png)$/i
            atta = Attachment.latest_attach(attachments, filename_utf8)
          end
          if atta && atta.readable? && atta.visible?
            return atta
          else
            return nil
          end
        end
      end
    end
  end
end
