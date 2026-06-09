# frozen_string_literal: true

require_relative '../application_system_test_case'

class SelectionIndentSystemTest < ApplicationSystemTestCase
  def setup
    super
    log_user('jsmith', 'jsmith')
  end

  def test_tab_indents_selected_text
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        text = "hello\nworld"
        el = find('#issue_description')
        el.click
        set_textarea_value 'issue_description', text, selection: [0, text.length]
        el.send_keys(:tab)
        assert_equal "  hello\n  world", el.value
      end
    end
  end

  def test_tab_indents_only_lines_within_selection
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        text = "line1\nline2\nline3"
        start = text.index("line2")
        el = find('#issue_description')
        el.click
        set_textarea_value 'issue_description', text, selection: [start, start + "line2".length]
        el.send_keys(:tab)
        assert_equal "line1\n  line2\nline3", el.value
      end
    end
  end

  def test_tab_does_not_indent_without_selection
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        fill_in 'Description', with: "hello"
        el = find('#issue_description')
        el.click
        el.send_keys(:tab)
        assert_equal "hello", el.value
      end
    end
  end

  def test_tab_does_not_indent_line_after_trailing_newline_in_selection
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        text = "line1\nline2\nline3"
        el = find('#issue_description')
        el.click
        # Select "line1\n" — selection ends at the start of line2
        set_textarea_value 'issue_description', text, selection: [0, "line1\n".length]
        el.send_keys(:tab)
        assert_equal "  line1\nline2\nline3", el.value
      end
    end
  end

  def test_shift_tab_unindents_selected_text
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        # Test lines with different indentation levels
        text = "    hello\n  beautiful\nnew\n\tworld"
        el = find('#issue_description')
        el.click
        set_textarea_value 'issue_description', text, selection: [0, text.length]
        el.send_keys([:shift, :tab])
        assert_equal "  hello\nbeautiful\nnew\n\tworld", el.value
      end
    end
  end

  def test_shift_tab_removes_partial_indent
    # Removes only as many spaces as exist when indent is less than the step size
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        text = "  hello\n world"
        el = find('#issue_description')
        el.click
        set_textarea_value 'issue_description', text, selection: [0, text.length]
        el.send_keys([:shift, :tab])
        assert_equal "hello\nworld", el.value
      end
    end
  end

  private

  # Sets textarea to support multi-line input and custom selection.
  # Avoids `fill_in`, which sends keystrokes and can trigger list autofill.
  def set_textarea_value(id, text, selection: nil)
    page.execute_script(
      "const el = document.getElementById(arguments[0]);" \
      "el.value = arguments[1];" \
      "if (arguments[2]) {" \
      "  el.setSelectionRange(arguments[2][0], arguments[2][1]);" \
      "} else {" \
      "  el.setSelectionRange(el.value.length, el.value.length);" \
      "}",
      id,
      text,
      selection
    )
  end
end
