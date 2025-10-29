# frozen_string_literal: true

require_relative '../application_system_test_case'

class GanttsTest < ApplicationSystemTestCase
  setup do
    log_user('jsmith', 'jsmith')
  end

  test 'columns display toggle shows status priority assignee updated' do
    visit_gantt
    expand_options

    assert_no_selector 'td#status'
    assert_no_selector 'td#priority'
    assert_no_selector 'td#assigned_to'
    assert_no_selector 'td#updated_on'

    find('#draw_selected_columns').check

    assert_selector 'div.gantt_subjects_container.draw_selected_columns'
    assert_selector 'td#status'
    assert_selector 'td#priority'
    assert_selector 'td#assigned_to'
    assert_selector 'td#updated_on'
  end

  test 'related issues toggle displays and hides relation arrows' do
    visit_gantt
    expand_options

    assert_selector '#gantt_draw_area path', minimum: 1

    find('#draw_relations').uncheck

    assert_no_selector '#gantt_draw_area path'

    find('#draw_relations').check

    assert_selector '#gantt_draw_area path', minimum: 1
  end

  test 'progress line toggle draws zigzag line' do
    visit_gantt
    expand_options

    find('#draw_relations').uncheck
    assert_no_selector '#gantt_draw_area path'

    find('#draw_progress_line').check

    assert_selector '#gantt_draw_area path', minimum: 1
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

    issue_subject = find('div.issue-subject.hascontextmenu', match: :first)
    issue_reference = issue_subject.find('a.issue', match: :first).text
    task_area = find('div.tooltip.hascontextmenu', match: :first, visible: :all)

    task_area.hover
    assert_selector 'div.tooltip span.tip', text: issue_reference

    issue_subject.right_click

    assert_selector '#context-menu'
    assert_selector '#context-menu a.icon-edit'

    page.send_keys(:escape)

    task_area = find('div.tooltip.hascontextmenu', match: :first, visible: :all)
    task_area.right_click

    assert_selector '#context-menu'
    assert_selector '#context-menu a.icon-edit'

    page.send_keys(:escape)
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
    page.evaluate_script("document.querySelector('td##{id}').offsetWidth")
  end

  def drag_column_resizer(column_id, distance)
    handle = find("td##{column_id} .ui-resizable-e")
    page.driver.browser.action.click_and_hold(handle.native).move_by(distance, 0).release.perform
  end
end
