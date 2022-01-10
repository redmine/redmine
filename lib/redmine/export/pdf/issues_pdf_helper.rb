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

module Redmine
  module Export
    module PDF
      module IssuesPdfHelper
        # Returns a PDF string of a single issue
        def issue_to_pdf(issue, assoc={})
          pdf = ITCPDF.new(current_language)
          pdf.set_title("#{issue.project} - #{issue.tracker} ##{issue.id}")
          pdf.alias_nb_pages
          pdf.footer_date = format_date(User.current.today)
          pdf.add_page
          pdf.SetFontStyle('B', 11)
          buf = "#{issue.project} - #{issue.tracker} ##{issue.id}"
          pdf.RDMMultiCell(190, 5, buf)
          pdf.SetFontStyle('', 8)
          base_x = pdf.get_x
          i = 1
          issue.ancestors.visible.each do |ancestor|
            pdf.set_x(base_x + i)
            buf = "#{ancestor.tracker} # #{ancestor.id} (#{ancestor.status.to_s}): #{ancestor.subject}"
            pdf.RDMMultiCell(190 - i, 5, buf)
            i += 1 if i < 35
          end
          pdf.SetFontStyle('B', 11)
          pdf.RDMMultiCell(190 - i, 5, issue.subject.to_s)
          pdf.SetFontStyle('', 8)
          pdf.RDMMultiCell(190, 5, "#{format_time(issue.created_on)} - #{issue.author}")
          pdf.ln

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
          left  << nil while left.size  < rows
          right << nil while right.size < rows

          custom_field_values = issue.visible_custom_field_values.reject {|value| value.custom_field.full_width_layout?}
          half = (custom_field_values.size / 2.0).ceil
          custom_field_values.each_with_index do |custom_value, i|
            (i < half ? left : right) << [custom_value.custom_field.name, show_value(custom_value, false)]
          end

          if pdf.get_rtl
            border_first_top = 'RT'
            border_last_top  = 'LT'
            border_first = 'R'
            border_last  = 'L'
          else
            border_first_top = 'LT'
            border_last_top  = 'RT'
            border_first = 'L'
            border_last  = 'R'
          end

          rows = left.size > right.size ? left.size : right.size
          rows.times do |i|
            heights = []
            pdf.SetFontStyle('B', 9)
            item = left[i]
            heights << pdf.get_string_height(35, item ? "#{item.first}:" : "")
            item = right[i]
            heights << pdf.get_string_height(35, item ? "#{item.first}:" : "")
            pdf.SetFontStyle('', 9)
            item = left[i]
            heights << pdf.get_string_height(60, item ? item.last.to_s  : "")
            item = right[i]
            heights << pdf.get_string_height(60, item ? item.last.to_s  : "")
            height = heights.max

            item = left[i]
            pdf.SetFontStyle('B', 9)
            pdf.RDMMultiCell(35, height, item ? "#{item.first}:" : "",
                             (i == 0 ? border_first_top : border_first), '', 0, 0)
            pdf.SetFontStyle('', 9)
            pdf.RDMMultiCell(60, height, item ? item.last.to_s : "",
                             (i == 0 ? border_last_top : border_last), '', 0, 0)

            item = right[i]
            pdf.SetFontStyle('B', 9)
            pdf.RDMMultiCell(35, height, item ? "#{item.first}:" : "",
                             (i == 0 ? border_first_top : border_first), '', 0, 0)
            pdf.SetFontStyle('', 9)
            pdf.RDMMultiCell(60, height, item ? item.last.to_s : "",
                             (i == 0 ? border_last_top : border_last), '', 0, 2)

            pdf.set_x(base_x)
          end

          pdf.SetFontStyle('B', 9)
          pdf.RDMCell(35 + 155, 5, l(:field_description), "LRT", 1)
          pdf.SetFontStyle('', 9)

          # Set resize image scale
          pdf.set_image_scale(1.6)
          text = pdf_format_text(issue, :description)
          pdf.RDMwriteFormattedCell(35+155, 5, '', '', text, issue.attachments, "LRB")

          custom_field_values = issue.visible_custom_field_values.select {|value| value.custom_field.full_width_layout?}
          custom_field_values.each do |value|
            is_html = value.custom_field.full_text_formatting?
            text = show_value(value, is_html)
            next if text.blank?

            pdf.SetFontStyle('B', 9)
            pdf.RDMCell(35+155, 5, value.custom_field.name, "LRT", 1)
            pdf.SetFontStyle('', 9)
            if is_html
              pdf.RDMwriteFormattedCell(35+155, 5, '', '', text, issue.attachments, "LRB")
            else
              pdf.RDMwriteHTMLCell(35+155, 5, '', '', text, issue.attachments, "LRB")
            end
          end

          unless issue.leaf?
            truncate_length = (!is_cjk? ? 90 : 65)
            pdf.SetFontStyle('B', 9)
            pdf.RDMCell(35+155, 5, l(:label_subtask_plural) + ":", "LTR")
            pdf.ln
            issue_list(issue.descendants.visible.sort_by(&:lft)) do |child, level|
              buf = "#{child.tracker} # #{child.id}: #{child.subject}".
                      truncate(truncate_length)
              level = 10 if level >= 10
              pdf.SetFontStyle('', 8)
              pdf.RDMCell(35 + 135, 5, (level >=1 ? "  " * level : "") + buf, border_first)
              pdf.SetFontStyle('B', 8)
              pdf.RDMCell(20, 5, child.status.to_s, border_last)
              pdf.ln
            end
          end

          relations = issue.relations.select {|r| r.other_issue(issue).visible?}
          unless relations.empty?
            truncate_length = (!is_cjk? ? 80 : 60)
            pdf.SetFontStyle('B', 9)
            pdf.RDMCell(35 + 155, 5, l(:label_related_issues) + ":", "LTR")
            pdf.ln
            relations.each do |relation|
              buf = relation.to_s(issue) do |other|
                text = ""
                if Setting.cross_project_issue_relations?
                  text += "#{relation.other_issue(issue).project} - "
                end
                text += "#{other.tracker} ##{other.id}: #{other.subject}"
                text
              end
              buf = buf.truncate(truncate_length)
              pdf.SetFontStyle('', 8)
              pdf.RDMCell(35+155-60, 5, buf, border_first)
              pdf.SetFontStyle('B', 8)
              pdf.RDMCell(20, 5, relation.other_issue(issue).status.to_s, "")
              pdf.RDMCell(20, 5, format_date(relation.other_issue(issue).start_date), "")
              pdf.RDMCell(20, 5, format_date(relation.other_issue(issue).due_date), border_last)
              pdf.ln
            end
          end
          pdf.RDMCell(190, 5, "", "T")
          pdf.ln

          if issue.changesets.any? &&
               User.current.allowed_to?(:view_changesets, issue.project)
            pdf.SetFontStyle('B', 9)
            pdf.RDMCell(190, 5, l(:label_associated_revisions), "B")
            pdf.ln
            issue.changesets.each do |changeset|
              pdf.SetFontStyle('B', 8)
              csstr  = "#{l(:label_revision)} #{changeset.format_identifier} - "
              csstr += format_time(changeset.committed_on) + " - " + changeset.author.to_s
              pdf.RDMCell(190, 5, csstr)
              pdf.ln
              unless changeset.comments.blank?
                pdf.SetFontStyle('', 8)
                pdf.RDMwriteHTMLCell(
                  190, 5, '', '',
                  changeset.comments.to_s, issue.attachments, ""
                )
              end
              pdf.ln
            end
          end

          if assoc[:journals].present?
            pdf.SetFontStyle('B', 9)
            pdf.RDMCell(190, 5, l(:label_history), "B")
            pdf.ln
            assoc[:journals].each do |journal|
              pdf.SetFontStyle('B', 8)
              title = "##{journal.indice} - #{format_time(journal.created_on)} - #{journal.user}"
              title += " (#{l(:field_private_notes)})" if journal.private_notes?
              pdf.RDMCell(190, 5, title)
              pdf.ln
              pdf.SetFontStyle('I', 8)
              details_to_strings(journal.visible_details, true).each do |string|
                pdf.RDMMultiCell(190, 5, "- " + string)
              end
              if journal.notes?
                pdf.ln unless journal.details.empty?
                pdf.SetFontStyle('', 8)
                text = pdf_format_text(journal, :notes)
                pdf.RDMwriteFormattedCell(190, 5, '', '', text, issue.attachments, "")
              end
              pdf.ln
            end
          end

          if issue.attachments.any?
            pdf.SetFontStyle('B', 9)
            pdf.RDMCell(190, 5, l(:label_attachment_plural), "B")
            pdf.ln
            issue.attachments.each do |attachment|
              pdf.SetFontStyle('', 8)
              pdf.RDMCell(80, 5, attachment.filename)
              pdf.RDMCell(20, 5, number_to_human_size(attachment.filesize), 0, 0, "R")
              pdf.RDMCell(25, 5, format_date(attachment.created_on), 0, 0, "R")
              pdf.RDMCell(65, 5, attachment.author.name, 0, 0, "R")
              pdf.ln
            end
          end
          pdf.output
        end

        # Returns a PDF string of a list of issues
        def issues_to_pdf(issues, project, query)
          pdf = ITCPDF.new(current_language, "L")
          title = query.new_record? ? l(:label_issue_plural) : query.name
          title = "#{project} - #{title}" if project
          pdf.set_title(title)
          pdf.alias_nb_pages
          pdf.footer_date = format_date(User.current.today)
          pdf.set_auto_page_break(false)
          pdf.add_page("L")

          # Landscape A4 = 210 x 297 mm
          page_height   = pdf.get_page_height # 210
          page_width    = pdf.get_page_width  # 297
          left_margin   = pdf.get_original_margins['left'] # 10
          right_margin  = pdf.get_original_margins['right'] # 10
          bottom_margin = pdf.get_footer_margin
          row_height    = 4

          # column widths
          table_width = page_width - right_margin - left_margin
          col_width = []
          unless query.inline_columns.empty?
            col_width = calc_col_width(issues, query, table_width, pdf)
            table_width = col_width.sum
          end

          # use full width if the query has block columns (description, last_notes or full width custom fieds)
          if table_width > 0 && query.block_columns.any?
            col_width = col_width.map {|w| w * (page_width - right_margin - left_margin) / table_width}
            table_width = col_width.sum
          end

          # title
          pdf.SetFontStyle('B', 11)
          pdf.RDMCell(190, 8, title)
          pdf.ln

          # totals
          totals = query.totals.map {|column, total| "#{column.caption}: #{total}"}
          if totals.present?
            pdf.SetFontStyle('B', 10)
            pdf.RDMCell(table_width, 6, totals.join("  "), 0, 1, 'R')
          end

          totals_by_group = query.totals_by_group
          render_table_header(pdf, query, col_width, row_height, table_width)
          previous_group = false
          result_count_by_group = query.result_count_by_group

          issue_list(issues) do |issue, level|
            if query.grouped? &&
                 (group = query.group_by_column.group_value(issue)) != previous_group
              pdf.SetFontStyle('B', 10)
              group_label = group.blank? ? +'None' : group.to_s.dup
              group_label << " (#{result_count_by_group[group]})"
              pdf.bookmark group_label, 0, -1
              pdf.RDMCell(table_width, row_height * 2, group_label, 'LR', 1, 'L')
              pdf.SetFontStyle('', 8)

              totals = totals_by_group.map {|column, total| "#{column.caption}: #{total[group]}"}.join("  ")
              if totals.present?
                pdf.RDMCell(table_width, row_height, totals, 'LR', 1, 'L')
              end
              previous_group = group
            end

            # fetch row values
            col_values = fetch_row_values(issue, query, level)

            # make new page if it doesn't fit on the current one
            base_y     = pdf.get_y
            max_height = get_issues_to_pdf_write_cells(pdf, col_values, col_width)
            space_left = page_height - base_y - bottom_margin
            if max_height > space_left
              pdf.add_page("L")
              render_table_header(pdf, query, col_width, row_height, table_width)
              base_y = pdf.get_y
            end

            # write the cells on page
            issues_to_pdf_write_cells(pdf, col_values, col_width, max_height)
            pdf.set_y(base_y + max_height)

            query.block_columns.each do |column|
              is_html = false
              if column.is_a?(QueryCustomFieldColumn)
                cv =
                  issue.visible_custom_field_values.detect do |v|
                    v.custom_field_id == column.custom_field.id
                  end
                is_html = cv.custom_field.full_text_formatting?
                text = show_value(cv, is_html)
              else
                text = pdf_format_text issue, column.name.to_sym
                is_html = true
              end
              next if text.blank?

              pdf.set_x(10)
              pdf.set_auto_page_break(true, bottom_margin)
              pdf.SetFontStyle('B', 9)
              pdf.RDMCell(0, 5, column.caption, "LRT", 1)
              pdf.SetFontStyle('', 9)
              if is_html
                pdf.RDMwriteFormattedCell(0, 5, '', '', text, issue.attachments, "LRB")
              else
                pdf.RDMwriteHTMLCell(0, 5, '', '', text, [], "LRB")
              end
              pdf.set_auto_page_break(false)
            end
          end

          if issues.size == Setting.issues_export_limit.to_i
            pdf.SetFontStyle('B', 10)
            pdf.RDMCell(0, row_height, '...')
          end
          pdf.output
        end

        def pdf_format_text(object, attribute)
          textilizable(object, attribute,
                       :only_path => false,
                       :edit_section_links => false,
                       :headings => false,
                       :inline_attachments => false
          )
        end

        def is_cjk?
          case current_language.to_s.downcase
          when 'ja', 'zh-tw', 'zh', 'ko'
            true
          else
            false
          end
        end

        # fetch row values
        def fetch_row_values(issue, query, level)
          query.inline_columns.collect do |column|
            s =
              if column.is_a?(QueryCustomFieldColumn)
                cv = issue.visible_custom_field_values.detect {|v| v.custom_field_id == column.custom_field.id}
                show_value(cv, false)
              else
                value = column.value_object(issue)
                case column.name
                when :subject
                  value = "  " * level + value
                when :attachments
                  value = value.to_a.map {|a| a.filename}.join("\n")
                end
                if value.is_a?(Date)
                  format_date(value)
                elsif value.is_a?(Time)
                  format_time(value)
                elsif value.is_a?(Float)
                  sprintf "%.2f", value
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
          pdf.SetFontStyle('B', 8)
          margins = pdf.get_margins
          col_padding = margins['cell']
          col_width_min = query.inline_columns.map {|v| pdf.get_string_width(v.caption) + col_padding}
          col_width_max = Array.new(col_width_min)
          col_width_avg = Array.new(col_width_min)
          col_min = pdf.get_string_width('OO') + col_padding * 2
          if table_width > col_min * col_width_avg.length
            table_width -= col_min * col_width_avg.length
          else
            col_min = pdf.get_string_width('O') + col_padding * 2
            if table_width > col_min * col_width_avg.length
              table_width -= col_min * col_width_avg.length
            else
              ratio = table_width / col_width_avg.sum
              return col_width = col_width_avg.map {|w| w * ratio}
            end
          end
          word_width_max = query.inline_columns.map do |c|
            n = 10
            c.caption.split.each do |w|
              x = pdf.get_string_width(w) + col_padding
              n = x if n < x
            end
            n
          end

          #  by properties of issues
          pdf.SetFontStyle('', 8)
          k = 1
          issue_list(issues) do |issue, level|
            k += 1
            values = fetch_row_values(issue, query, level)
            values.each_with_index do |v, i|
              n = pdf.get_string_width(v) + col_padding * 2
              col_width_max[i] = n if col_width_max[i] < n
              col_width_min[i] = n if col_width_min[i] > n
              col_width_avg[i] += n
              v.split.each do |w|
                x = pdf.get_string_width(w) + col_padding
                word_width_max[i] = x if word_width_max[i] < x
              end
            end
          end
          col_width_avg.map! {|x| x / k}

          # calculate columns width
          ratio = table_width / col_width_avg.sum
          col_width = col_width_avg.map {|w| w * ratio}

          # correct max word width if too many columns
          ratio = table_width / word_width_max.sum
          word_width_max.map! {|v| v * ratio} if ratio < 1

          # correct and lock width of some columns
          done = 1
          col_fix = []
          col_width.each_with_index do |w, i|
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
            ratio = table_width / col_width.sum

            # correct columns width
            col_width.each_with_index do |w, i|
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

          ratio = table_width / col_width.sum
          col_width.map! {|v| v * ratio + col_min}
          col_width
        end

        def render_table_header(pdf, query, col_width, row_height, table_width)
          # headers
          pdf.SetFontStyle('B', 8)
          pdf.set_fill_color(230, 230, 230)

          base_x     = pdf.get_x
          base_y     = pdf.get_y
          max_height = get_issues_to_pdf_write_cells(pdf, query.inline_columns, col_width, true)

          # write the cells on page
          issues_to_pdf_write_cells(pdf, query.inline_columns, col_width, max_height, true)
          pdf.set_xy(base_x, base_y + max_height)

          # rows
          pdf.SetFontStyle('', 8)
          pdf.set_fill_color(255, 255, 255)
        end

        # returns the maximum height of MultiCells
        def get_issues_to_pdf_write_cells(pdf, col_values, col_widths, head=false)
          heights = []
          col_values.each_with_index do |column, i|
            heights << pdf.get_string_height(col_widths[i], head ? column.caption : column)
          end
          return heights.max
        end

        # Renders MultiCells and returns the maximum height used
        def issues_to_pdf_write_cells(pdf, col_values, col_widths, row_height, head=false)
          col_values.each_with_index do |column, i|
            pdf.RDMMultiCell(col_widths[i], row_height, head ? column.caption : column.strip, 1, '', 1, 0)
          end
        end

        # Draw lines to close the row (MultiCell border drawing in not uniform)
        #
        #  parameter "col_id_width" is not used. it is kept for compatibility.
        def issues_to_pdf_draw_borders(pdf, top_x, top_y, lower_y,
                                       col_id_width, col_widths, rtl=false)
          col_x = top_x
          pdf.line(col_x, top_y, col_x, lower_y)    # id right border
          col_widths.each do |width|
            if rtl
              col_x -= width
            else
              col_x += width
            end
            pdf.line(col_x, top_y, col_x, lower_y)  # columns right border
          end
          pdf.line(top_x, top_y, top_x, lower_y)    # left border
          pdf.line(top_x, lower_y, col_x, lower_y)  # bottom border
        end
      end
    end
  end
end
