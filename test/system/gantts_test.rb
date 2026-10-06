# frozen_string_literal: true

require_relative '../application_system_test_case'

class GanttsTest < ApplicationSystemTestCase
  setup do
    log_user('jsmith', 'jsmith')
  end

  test 'columns display toggle shows status priority assignee updated' do
    visit_gantt
    expand_options

    assert_no_selector 'div.gantt-column[data-gantt-column=status]'
    assert_no_selector 'div.gantt-column[data-gantt-column=priority]'
    assert_no_selector 'div.gantt-column[data-gantt-column=assigned_to]'
    assert_no_selector 'div.gantt-column[data-gantt-column=updated_on]'

    find('#draw_selected_columns').check

    assert_selector 'div.gantt-column[data-gantt-column=subjects]'
    assert_selector 'div.gantt-column[data-gantt-column=status]'
    assert_selector 'div.gantt-column[data-gantt-column=priority]'
    assert_selector 'div.gantt-column[data-gantt-column=assigned_to]'
    assert_selector 'div.gantt-column[data-gantt-column=updated_on]'
  end

  test 'tree toggle updates the same logical rows across every pane' do
    visit_gantt
    expand_options
    find('#draw_selected_columns').check

    project_row = find('[data-gantt-column="subjects"] .gantt-row[data-gantt-row-key="project-1"]')
    subject_issue = '[data-gantt-column="subjects"] .gantt-row[data-gantt-row-key="issue-3"]'
    column_issue = '[data-gantt-column="status"] .gantt-row[data-gantt-row-key="issue-3"]'
    timeline_issue = '.gantt-timeline-body .gantt-row[data-gantt-row-key="issue-3"]'

    project_row.find('.expander').click

    assert_selector subject_issue, visible: :hidden
    assert_selector column_issue, visible: :hidden
    assert_selector timeline_issue, visible: :hidden

    project_row.find('.expander').click

    assert_selector subject_issue, visible: :visible
    assert_selector column_issue, visible: :visible
    assert_selector timeline_issue, visible: :visible
  end

  test 'row highlight spans subjects selected columns and timeline' do
    visit_gantt
    expand_options
    find('#draw_selected_columns').check

    find('.gantt-timeline-body .gantt-row[data-gantt-row-key="issue-1"] .tooltip').hover

    assert_selector '[data-gantt-column="subjects"] .gantt-row.gantt-row-hover[data-gantt-row-key="issue-1"]'
    assert_selector '[data-gantt-column="status"] .gantt-row.gantt-row-hover[data-gantt-row-key="issue-1"]'
  end

  test 'related issues toggle displays and hides relation arrows' do
    visit_gantt
    expand_options

    assert_selector '.gantt-relations path', minimum: 1

    find('#draw_relations').uncheck

    assert_no_selector '.gantt-relations path'

    find('#draw_relations').check

    assert_selector '.gantt-relations path', minimum: 1

    # Relation arrows should keep the same position when redrawn after horizontal scrolling.
    paths_before_scroll = all('.gantt-relations path').pluck(:d)
    find('#draw_relations').uncheck
    find('.gantt-timeline').scroll_to(200, 0)
    find('#draw_relations').check

    assert_equal paths_before_scroll, all('.gantt-relations path').pluck(:d)
  end

  test 'progress line option displays progress line' do
    visit_gantt
    expand_options

    find('#draw_relations').uncheck
    assert_no_selector '.gantt-relations path'

    find('#draw_progress_line').check

    assert_selector '.gantt-relations path', minimum: 1
  end

  test 'selected columns can be resized by dragging' do
    visit_gantt
    expand_options

    find('#draw_selected_columns').check

    width_before = column_width('status')
    drag_column_resizer('status', 80)
    width_after = column_width('status')

    assert width_after > width_before
  end

  test 'context menu and tooltip interactions' do
    visit_gantt

    issue1_subject_row = find('.gantt-column[data-gantt-column="subjects"] .gantt-row[data-gantt-row-key="issue-1"]')
    issue1_task_bar = find('.gantt-timeline .gantt-row[data-gantt-row-key="issue-1"] .tooltip')

    # Tooltip for issue task bar
    issue1_task_bar.hover

    within issue1_task_bar do
      issue_link_text = issue1_subject_row.first('a.issue', visible: :all).text
      assert_selector '.tip', text: issue_link_text
    end
    # Context menu for issue subject
    issue1_subject_row.right_click

    assert_selector '#context-menu'
    assert_selector '#context-menu a.icon-edit'

    # Click outside the context menu to close it
    issue1_subject_row.click(x: -1, y: 0)
    assert_no_selector '#context-menu'

    # Context menu for issue task bar
    issue1_task_bar.right_click

    assert_selector '#context-menu'
    assert_selector '#context-menu a.icon-edit'
  end

  private

  def visit_gantt
    visit '/projects/ecookbook/issues/gantt'
  end

  def expand_options
    legend = find('fieldset#options legend')
    legend.click if legend[:class].to_s.include?('collapsed')
  end

  def column_width(id)
    page.evaluate_script("document.querySelector('div.gantt-column[data-gantt-column=\"#{id}\"]').offsetWidth")
  end

  def drag_column_resizer(column_id, distance)
    handle = find("div.gantt-column[data-gantt-column=\"#{column_id}\"] .ui-resizable-e")
    page.driver.browser.action.click_and_hold(handle.native).move_by(distance, 0).release.perform
  end
end
