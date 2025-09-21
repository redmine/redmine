# frozen_string_literal: true

require_relative '../application_system_test_case'

class ListAutofillSystemTest < ApplicationSystemTestCase
  def setup
    super
    log_user('jsmith', 'jsmith')
  end

  def test_autofill_textile_unordered_list
    with_settings :text_formatting => 'textile' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        find('#issue_description').send_keys('* First item')
        find('#issue_description').send_keys(:enter)

        assert_equal(
          "* First item\n" \
          "* ",
          find('#issue_description').value
        )
      end
    end
  end

  def test_autofill_textile_ordered_list
    with_settings :text_formatting => 'textile' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        find('#issue_description').send_keys('# First item')
        find('#issue_description').send_keys(:enter)

        assert_equal(
          "# First item\n" \
          "# ",
          find('#issue_description').value
        )
      end
    end
  end

  def test_remove_list_marker_for_empty_item
    with_settings :text_formatting => 'textile' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        find('#issue_description').send_keys('* First item')
        find('#issue_description').send_keys(:enter)
        find('#issue_description').send_keys(:enter)  # Press Enter on empty line removes the marker

        assert_equal(
          "* First item\n",
          find('#issue_description').value
        )
      end
    end
  end

  def test_autofill_markdown_unordered_list
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        find('#issue_description').send_keys('- First item')
        find('#issue_description').send_keys(:enter)
        assert_equal(
          "- First item\n" \
          "- ",
          find('#issue_description').value
        )

        fill_in 'Description', with: ''
        find('#issue_description').send_keys('* First item')
        find('#issue_description').send_keys(:enter)
        assert_equal(
          "* First item\n" \
          "* ",
          find('#issue_description').value
        )

        fill_in 'Description', with: ''
        find('#issue_description').send_keys('+ First item')
        find('#issue_description').send_keys(:enter)
        assert_equal(
          "+ First item\n" \
          "+ ",
          find('#issue_description').value
        )
      end
    end
  end

  def test_autofill_with_markdown_ordered_list
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        find('#issue_description').send_keys('1. First item')
        find('#issue_description').send_keys(:enter)

        assert_equal(
          "1. First item\n" \
          "2. ",
          find('#issue_description').value
        )
      end
    end
  end

  def test_autofill_with_markdown_ordered_list_using_parenthesis
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        find('#issue_description').send_keys('1) First item')
        find('#issue_description').send_keys(:enter)

        assert_equal(
          "1) First item\n" \
          "2) ",
          find('#issue_description').value
        )
      end
    end
  end

  def test_textile_nested_list_autofill
    with_settings :text_formatting => 'textile' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        find('#issue_description').send_keys('* Parent item')
        find('#issue_description').send_keys(:enter)
        find('#issue_description').send_keys(:backspace, :backspace)  # Remove auto-filled marker
        find('#issue_description').send_keys('** Child item')
        find('#issue_description').send_keys(:enter)
        find('#issue_description').send_keys(:backspace, :backspace, :backspace)  # Remove auto-filled marker
        find('#issue_description').send_keys("*** Grandchild item")
        find('#issue_description').send_keys(:enter)

        assert_equal(
          "* Parent item\n" \
          "** Child item\n" \
          "*** Grandchild item\n" \
          "*** ",
          find('#issue_description').value
        )
      end
    end
  end

  def test_common_mark_nested_list_autofill
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        find('#issue_description').send_keys('- Parent item')
        find('#issue_description').send_keys(:enter)
        find('#issue_description').send_keys(:backspace, :backspace)  # Remove auto-filled marker
        find('#issue_description').send_keys('  - Child item')
        find('#issue_description').send_keys(:enter)

        assert_equal(
          "- Parent item\n" \
          "  - Child item\n" \
          "  - ",
          find('#issue_description').value
        )

        find('#issue_description').send_keys(:backspace, :backspace, :backspace, :backspace)  # Remove auto-filled marker
        find('#issue_description').send_keys('    - Grandchild item')
        find('#issue_description').send_keys(:enter)

        assert_equal(
          "- Parent item\n" \
          "  - Child item\n" \
          "    - Grandchild item\n" \
          "    - ",
          find('#issue_description').value
        )
      end
    end
  end

  def test_common_mark_mixed_list_types
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        find('#issue_description').send_keys('1. First numbered item')
        find('#issue_description').send_keys(:enter)
        find('#issue_description').send_keys(:backspace, :backspace, :backspace)  # Remove auto-filled numbered list marker
        find('#issue_description').send_keys('   - Nested bullet item')
        find('#issue_description').send_keys(:enter)

        assert_equal(
          "1. First numbered item\n" \
          "   - Nested bullet item\n" \
          "   - ",
          find('#issue_description').value
        )

        find('#issue_description').send_keys(:backspace, :backspace, :backspace, :backspace, :backspace)  # Remove auto-filled numbered list marker
        find('#issue_description').send_keys('2. Second numbered item')
        find('#issue_description').send_keys(:enter)

        assert_equal(
          "1. First numbered item\n" \
          "   - Nested bullet item\n" \
          "2. Second numbered item\n" \
          "3. ",
          find('#issue_description').value
        )
      end
    end
  end

  def test_remove_list_marker_with_single_halfwidth_space_variants
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        find('#issue_description').click

        # Half-width space only → should remove marker
        find('#issue_description').send_keys('1. First item', :enter)
        assert_equal("1. First item\n2. ", find('#issue_description').value)
        find('#issue_description').send_keys(:enter)
        assert_equal("1. First item\n", find('#issue_description').value)

        fill_in 'Description', with: ''
        # Full-width space only → should NOT remove marker
        find('#issue_description').send_keys('1. First item', :enter)
        find('#issue_description').send_keys(:backspace, :backspace, :backspace)
        find('#issue_description').send_keys("2.　", :enter)
        assert_equal("1. First item\n2.　\n", find('#issue_description').value)

        fill_in 'Description', with: ''
        # Two or more spaces → should NOT remove marker
        find('#issue_description').send_keys('1. First item', :enter)
        find('#issue_description').send_keys(:backspace, :backspace, :backspace)
        find('#issue_description').send_keys("2.  ", :enter)
        assert_equal("1. First item\n2.  \n3. ", find('#issue_description').value)
      end
    end
  end

  def test_no_autofill_when_content_is_missing_or_invalid_marker
    with_settings :text_formatting => 'common_mark' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        find('#issue_description').click

        # Marker only with no content → should not trigger insert
        find('#issue_description').send_keys('1.', :enter)
        assert_equal("1.\n", find('#issue_description').value)

        fill_in 'Description', with: ''
        # Invalid marker pattern (e.g. double dot) → should not trigger insert
        find('#issue_description').send_keys('1.. Invalid marker', :enter)
        assert_equal("1.. Invalid marker\n", find('#issue_description').value)
      end
    end
  end

  def test_autofill_ignored_with_none_text_formatting
    with_settings :text_formatting => '' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        find('#issue_description').click

        # Unsupported format → no autofill should occur
        find('#issue_description').send_keys('* First item', :enter)
        assert_equal("* First item\n", find('#issue_description').value)
      end
    end
  end

  def test_marker_not_inserted_on_empty_line
    with_settings :text_formatting => 'textile' do
      visit '/projects/ecookbook/issues/new'

      within('form#issue-form') do
        find('#issue_description').click

        # Pressing enter on an empty line → should not trigger insert
        find('#issue_description').send_keys(:enter)
        assert_equal("\n", find('#issue_description').value)
      end
    end
  end
end
