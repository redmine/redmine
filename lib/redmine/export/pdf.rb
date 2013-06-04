# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

require 'tcpdf'
require 'fpdf/chinese'
require 'fpdf/japanese'
require 'fpdf/korean'

if RUBY_VERSION < '1.9'
  require 'iconv'
end

module Redmine
  module Export
    module PDF
      include ActionView::Helpers::TextHelper
      include ActionView::Helpers::NumberHelper
      include IssuesHelper

      class ITCPDF < TCPDF
        include Redmine::I18n
        attr_accessor :footer_date

        def initialize(lang, orientation='P')
          @@k_path_cache = Rails.root.join('tmp', 'pdf')
          FileUtils.mkdir_p @@k_path_cache unless File::exist?(@@k_path_cache)
          set_language_if_valid lang
          pdf_encoding = l(:general_pdf_encoding).upcase
          super(orientation, 'mm', 'A4', (pdf_encoding == 'UTF-8'), pdf_encoding)
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
          @outlines = []
          @outlineRoot = nil
        end

        def SetFontStyle(style, size)
          SetFont(@font_for_content, style, size)
        end

        def SetTitle(txt)
          txt = begin
            utf16txt = to_utf16(txt)
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

        def formatted_text(text)
          html = Redmine::WikiFormatting.to_html(Setting.text_formatting, text)
          # Strip {{toc}} tags
          html.gsub!(/<p>\{\{([<>]?)toc\}\}<\/p>/i, '')
          html
        end

        # Encodes an UTF-8 string to UTF-16BE
        def to_utf16(str)
          if str.respond_to?(:encode)
            str.encode('UTF-16BE')
          else
            Iconv.conv('UTF-16BE', 'UTF-8', str)
          end
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
            fix_text_encoding(formatted_text(txt)),
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

        def Bookmark(txt, level=0, y=0)
          if (y == -1)
            y = GetY()
          end
          @outlines << {:t => txt, :l => level, :p => PageNo(), :y => (@h - y)*@k}
        end

        def bookmark_title(txt)
          txt = begin
            utf16txt = to_utf16(txt)
            hextxt = "<FEFF"  # FEFF is BOM
            hextxt << utf16txt.unpack("C*").map {|x| sprintf("%02X",x) }.join
            hextxt << ">"
          rescue
            txt
          end || ''
        end

        def putbookmarks
          nb=@outlines.size
          return if (nb==0)
          lru=[]
          level=0
          @outlines.each_with_index do |o, i|
            if(o[:l]>0)
              parent=lru[o[:l]-1]
              #Set parent and last pointers
              @outlines[i][:parent]=parent
              @outlines[parent][:last]=i
              if (o[:l]>level)
                #Level increasing: set first pointer
                @outlines[parent][:first]=i
              end
            else
              @outlines[i][:parent]=nb
            end
            if (o[:l]<=level && i>0)
              #Set prev and next pointers
              prev=lru[o[:l]]
              @outlines[prev][:next]=i
              @outlines[i][:prev]=prev
            end
            lru[o[:l]]=i
            level=o[:l]
          end
          #Outline items
          n=self.n+1
          @outlines.each_with_index do |o, i|
            newobj()
            out('<</Title '+bookmark_title(o[:t]))
            out("/Parent #{n+o[:parent]} 0 R")
            if (o[:prev])
              out("/Prev #{n+o[:prev]} 0 R")
            end
            if (o[:next])
              out("/Next #{n+o[:next]} 0 R")
            end
            if (o[:first])
              out("/First #{n+o[:first]} 0 R")
            end
            if (o[:last])
              out("/Last #{n+o[:last]} 0 R")
            end
            out("/Dest [%d 0 R /XYZ 0 %.2f null]" % [1+2*o[:p], o[:y]])
            out('/Count 0>>')
            out('endobj')
          end
          #Outline root
          newobj()
          @outlineRoot=self.n
          out("<</Type /Outlines /First #{n} 0 R");
          out("/Last #{n+lru[0]} 0 R>>");
          out('endobj');
        end

        def putresources()
          super
          putbookmarks()
        end

        def putcatalog()
          super
          if(@outlines.size > 0)
            out("/Outlines #{@outlineRoot} 0 R");
            out('/PageMode /UseOutlines');
          end
        end
      end

      # fetch row values
      def fetch_row_values(issue, query, level)
        query.inline_columns.collect do |column|
          s = if column.is_a?(QueryCustomFieldColumn)
            cv = issue.custom_field_values.detect {|v| v.custom_field_id == column.custom_field.id}
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
      end

      # calculate columns width
      def calc_col_width(issues, query, table_width, pdf)
        # calculate statistics
        #  by captions
        pdf.SetFontStyle('B',8)
        col_padding = pdf.GetStringWidth('OO')
        col_width_min = query.inline_columns.map {|v| pdf.GetStringWidth(v.caption) + col_padding}
        col_width_max = Array.new(col_width_min)
        col_width_avg = Array.new(col_width_min)
        word_width_max = query.inline_columns.map {|c|
          n = 10
          c.caption.split.each {|w|
            x = pdf.GetStringWidth(w) + col_padding
            n = x if n < x
          }
          n
        }

        #  by properties of issues
        pdf.SetFontStyle('',8)
        col_padding = pdf.GetStringWidth('OO')
        k = 1
        issue_list(issues) {|issue, level|
          k += 1
          values = fetch_row_values(issue, query, level)
          values.each_with_index {|v,i|
            n = pdf.GetStringWidth(v) + col_padding
            col_width_max[i] = n if col_width_max[i] < n
            col_width_min[i] = n if col_width_min[i] > n
            col_width_avg[i] += n
            v.split.each {|w|
              x = pdf.GetStringWidth(w) + col_padding
              word_width_max[i] = x if word_width_max[i] < x
            }
          }
        }
        col_width_avg.map! {|x| x / k}

        # calculate columns width
        ratio = table_width / col_width_avg.inject(0, :+)
        col_width = col_width_avg.map {|w| w * ratio}

        # correct max word width if too many columns
        ratio = table_width / word_width_max.inject(0, :+)
        word_width_max.map! {|v| v * ratio} if ratio < 1

        # correct and lock width of some columns
        done = 1
        col_fix = []
        col_width.each_with_index do |w,i|
          if w > col_width_max[i]
            col_width[i] = col_width_max[i]
            col_fix[i] = 1
            done = 0
          elsif w < word_width_max[i]
            col_width[i] = word_width_max[i]
            col_fix[i] = 1
            done = 0
          else
            col_fix[i] = 0
          end
        end

        # iterate while need to correct and lock coluns width
        while done == 0
          # calculate free & locked columns width
          done = 1
          fix_col_width = 0
          free_col_width = 0
          col_width.each_with_index do |w,i|
            if col_fix[i] == 1
              fix_col_width += w
            else
              free_col_width += w
            end
          end

          # calculate column normalizing ratio
          if free_col_width == 0
            ratio = table_width / col_width.inject(0, :+)
          else
            ratio = (table_width - fix_col_width) / free_col_width
          end

          # correct columns width
          col_width.each_with_index do |w,i|
            if col_fix[i] == 0
              col_width[i] = w * ratio

              # check if column width less then max word width
              if col_width[i] < word_width_max[i]
                col_width[i] = word_width_max[i]
                col_fix[i] = 1
                done = 0
              elsif col_width[i] > col_width_max[i]
                col_width[i] = col_width_max[i]
                col_fix[i] = 1
                done = 0
              end
            end
          end
        end
        col_width
      end

      def render_table_header(pdf, query, col_width, row_height, table_width)
        # headers
        pdf.SetFontStyle('B',8)
        pdf.SetFillColor(230, 230, 230)

        # render it background to find the max height used
        base_x = pdf.GetX
        base_y = pdf.GetY
        max_height = issues_to_pdf_write_cells(pdf, query.inline_columns, col_width, row_height, true)
        pdf.Rect(base_x, base_y, table_width, max_height, 'FD');
        pdf.SetXY(base_x, base_y);

        # write the cells on page
        issues_to_pdf_write_cells(pdf, query.inline_columns, col_width, row_height, true)
        issues_to_pdf_draw_borders(pdf, base_x, base_y, base_y + max_height, 0, col_width)
        pdf.SetY(base_y + max_height);

        # rows
        pdf.SetFontStyle('',8)
        pdf.SetFillColor(255, 255, 255)
      end

      # Returns a PDF string of a list of issues
      def issues_to_pdf(issues, project, query)
        pdf = ITCPDF.new(current_language, "L")
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
        left_margin   = 10
        right_margin  = 10
        bottom_margin = 20
        row_height    = 4

        # column widths
        table_width = page_width - right_margin - left_margin
        col_width = []
        unless query.inline_columns.empty?
          col_width = calc_col_width(issues, query, table_width, pdf)
          table_width = col_width.inject(0, :+)
        end

        # use full width if the description is displayed
        if table_width > 0 && query.has_column?(:description)
          col_width = col_width.map {|w| w * (page_width - right_margin - left_margin) / table_width}
          table_width = col_width.inject(0, :+)
        end

        # title
        pdf.SetFontStyle('B',11)
        pdf.RDMCell(190,10, title)
        pdf.Ln
        render_table_header(pdf, query, col_width, row_height, table_width)
        previous_group = false
        issue_list(issues) do |issue, level|
          if query.grouped? &&
               (group = query.group_by_column.value(issue)) != previous_group
            pdf.SetFontStyle('B',10)
            group_label = group.blank? ? 'None' : group.to_s.dup
            group_label << " (#{query.issue_count_by_group[group]})"
            pdf.Bookmark group_label, 0, -1
            pdf.RDMCell(table_width, row_height * 2, group_label, 1, 1, 'L')
            pdf.SetFontStyle('',8)
            previous_group = group
          end

          # fetch row values
          col_values = fetch_row_values(issue, query, level)

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
            render_table_header(pdf, query, col_width, row_height, table_width)
            base_x = pdf.GetX
            base_y = pdf.GetY
          end

          # write the cells on page
          issues_to_pdf_write_cells(pdf, col_values, col_width, row_height)
          issues_to_pdf_draw_borders(pdf, base_x, base_y, base_y + max_height, 0, col_width)
          pdf.SetY(base_y + max_height);

          if query.has_column?(:description) && issue.description?
            pdf.SetX(10)
            pdf.SetAutoPageBreak(true, 20)
            pdf.RDMwriteHTMLCell(0, 5, 10, 0, issue.description.to_s, issue.attachments, "LRBT")
            pdf.SetAutoPageBreak(false)
          end
        end

        if issues.size == Setting.issues_export_limit.to_i
          pdf.SetFontStyle('B',10)
          pdf.RDMCell(0, row_height, '...')
        end
        pdf.Output
      end

      # Renders MultiCells and returns the maximum height used
      def issues_to_pdf_write_cells(pdf, col_values, col_widths, row_height, head=false)
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
      #
      #  parameter "col_id_width" is not used. it is kept for compatibility.
      def issues_to_pdf_draw_borders(pdf, top_x, top_y, lower_y,
                                     col_id_width, col_widths)
        col_x = top_x
        pdf.Line(col_x, top_y, col_x, lower_y)    # id right border
        col_widths.each do |width|
          col_x += width
          pdf.Line(col_x, top_y, col_x, lower_y)  # columns right border
        end
        pdf.Line(top_x, top_y, top_x, lower_y)    # left border
        pdf.Line(top_x, lower_y, col_x, lower_y)  # bottom border
      end

      # Returns a PDF string of a single issue
      def issue_to_pdf(issue, assoc={})
        pdf = ITCPDF.new(current_language)
        pdf.SetTitle("#{issue.project} - #{issue.tracker} ##{issue.id}")
        pdf.alias_nb_pages
        pdf.footer_date = format_date(Date.today)
        pdf.AddPage
        pdf.SetFontStyle('B',11)
        buf = "#{issue.project} - #{issue.tracker} ##{issue.id}"
        pdf.RDMMultiCell(190, 5, buf)
        pdf.SetFontStyle('',8)
        base_x = pdf.GetX
        i = 1
        issue.ancestors.visible.each do |ancestor|
          pdf.SetX(base_x + i)
          buf = "#{ancestor.tracker} # #{ancestor.id} (#{ancestor.status.to_s}): #{ancestor.subject}"
          pdf.RDMMultiCell(190 - i, 5, buf)
          i += 1 if i < 35
        end
        pdf.SetFontStyle('B',11)
        pdf.RDMMultiCell(190 - i, 5, issue.subject.to_s)
        pdf.SetFontStyle('',8)
        pdf.RDMMultiCell(190, 5, "#{format_time(issue.created_on)} - #{issue.author}")
        pdf.Ln

        left = []
        left << [l(:field_status), issue.status]
        left << [l(:field_priority), issue.priority]
        left << [l(:field_assigned_to), issue.assigned_to] unless issue.disabled_core_fields.include?('assigned_to_id')
        left << [l(:field_category), issue.category] unless issue.disabled_core_fields.include?('category_id')
        left << [l(:field_fixed_version), issue.fixed_version] unless issue.disabled_core_fields.include?('fixed_version_id')

        right = []
        right << [l(:field_start_date), format_date(issue.start_date)] unless issue.disabled_core_fields.include?('start_date')
        right << [l(:field_due_date), format_date(issue.due_date)] unless issue.disabled_core_fields.include?('due_date')
        right << [l(:field_done_ratio), "#{issue.done_ratio}%"] unless issue.disabled_core_fields.include?('done_ratio')
        right << [l(:field_estimated_hours), l_hours(issue.estimated_hours)] unless issue.disabled_core_fields.include?('estimated_hours')
        right << [l(:label_spent_time), l_hours(issue.total_spent_hours)] if User.current.allowed_to?(:view_time_entries, issue.project)

        rows = left.size > right.size ? left.size : right.size
        while left.size < rows
          left << nil
        end
        while right.size < rows
          right << nil
        end

        half = (issue.custom_field_values.size / 2.0).ceil
        issue.custom_field_values.each_with_index do |custom_value, i|
          (i < half ? left : right) << [custom_value.custom_field.name, show_value(custom_value)]
        end

        rows = left.size > right.size ? left.size : right.size
        rows.times do |i|
          item = left[i]
          pdf.SetFontStyle('B',9)
          pdf.RDMCell(35,5, item ? "#{item.first}:" : "", i == 0 ? "LT" : "L")
          pdf.SetFontStyle('',9)
          pdf.RDMCell(60,5, item ? item.last.to_s : "", i == 0 ? "RT" : "R")

          item = right[i]
          pdf.SetFontStyle('B',9)
          pdf.RDMCell(35,5, item ? "#{item.first}:" : "", i == 0 ? "LT" : "L")
          pdf.SetFontStyle('',9)
          pdf.RDMCell(60,5, item ? item.last.to_s : "", i == 0 ? "RT" : "R")
          pdf.Ln
        end

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
          issue_list(issue.descendants.visible.sort_by(&:lft)) do |child, level|
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

        if assoc[:journals].present?
          pdf.SetFontStyle('B',9)
          pdf.RDMCell(190,5, l(:label_history), "B")
          pdf.Ln
          assoc[:journals].each do |journal|
            pdf.SetFontStyle('B',8)
            title = "##{journal.indice} - #{format_time(journal.created_on)} - #{journal.user}"
            title << " (#{l(:field_private_notes)})" if journal.private_notes?
            pdf.RDMCell(190,5, title)
            pdf.Ln
            pdf.SetFontStyle('I',8)
            details_to_strings(journal.details, true).each do |string|
              pdf.RDMMultiCell(190,5, "- " + string)
            end
            if journal.notes?
              pdf.Ln unless journal.details.empty?
              pdf.SetFontStyle('',8)
              pdf.RDMwriteHTMLCell(190,5,0,0,
                    journal.notes.to_s, issue.attachments, "")
            end
            pdf.Ln
          end
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

      # Returns a PDF string of a set of wiki pages
      def wiki_pages_to_pdf(pages, project)
        pdf = ITCPDF.new(current_language)
        pdf.SetTitle(project.name)
        pdf.alias_nb_pages
        pdf.footer_date = format_date(Date.today)
        pdf.AddPage
        pdf.SetFontStyle('B',11)
        pdf.RDMMultiCell(190,5, project.name)
        pdf.Ln
        # Set resize image scale
        pdf.SetImageScale(1.6)
        pdf.SetFontStyle('',9)
        write_page_hierarchy(pdf, pages.group_by(&:parent_id))
        pdf.Output
      end

      # Returns a PDF string of a single wiki page
      def wiki_page_to_pdf(page, project)
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
        write_wiki_page(pdf, page)
        pdf.Output
      end

      def write_page_hierarchy(pdf, pages, node=nil, level=0)
        if pages[node]
          pages[node].each do |page|
            if @new_page
              pdf.AddPage
            else
              @new_page = true
            end
            pdf.Bookmark page.title, level
            write_wiki_page(pdf, page)
            write_page_hierarchy(pdf, pages, page.id, level + 1) if pages[page.id]
          end
        end
      end

      def write_wiki_page(pdf, page)
        pdf.RDMwriteHTMLCell(190,5,0,0,
              page.content.text.to_s, page.attachments, 0)
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
