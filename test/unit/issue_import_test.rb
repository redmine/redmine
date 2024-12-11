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

require_relative '../test_helper'

class IssueImportTest < ActiveSupport::TestCase
  include Redmine::I18n

  def setup
    User.current = nil
    set_language_if_valid 'en'
  end

  def test_authorized
    assert  IssueImport.authorized?(User.find(1)) # admins
    assert  IssueImport.authorized?(User.find(2)) # has import_issues permission
    assert !IssueImport.authorized?(User.find(3)) # does not have permission
  end

  def test_create_versions_should_create_missing_versions
    import = generate_import_with_mapping
    import.mapping.merge!('fixed_version' => '9', 'create_versions' => '1')
    import.save!

    version = new_record(Version) do
      assert_difference 'Issue.count', 3 do
        import.run
      end
    end
    assert_equal '2.1', version.name
  end

  def test_create_categories_should_create_missing_categories
    import = generate_import_with_mapping
    import.mapping.merge!('category' => '10', 'create_categories' => '1')
    import.save!

    category = new_record(IssueCategory) do
      assert_difference 'Issue.count', 3 do
        import.run
      end
    end
    assert_equal 'New category', category.name
  end

  def test_mapping_with_fixed_tracker
    import = generate_import_with_mapping
    import.mapping['tracker'] = 'value:2'
    import.save!

    issues = new_records(Issue, 3) {import.run}
    assert_equal [2], issues.map(&:tracker_id).uniq
  end

  def test_mapping_with_mapped_tracker
    import = generate_import_with_mapping
    import.mapping['tracker'] = '13'
    import.save!

    issues = new_records(Issue, 3) {import.run}
    assert_equal [1, 2, 1], issues.map(&:tracker_id)
  end

  def test_should_not_import_with_default_tracker_when_tracker_is_invalid
    Tracker.find_by_name('Feature request').update!(:name => 'Feature')

    import = generate_import_with_mapping
    import.mapping['tracker'] = '13'
    import.save!
    import.run

    assert_equal 1, import.unsaved_items.count
    item = import.unsaved_items.first
    assert_include "Tracker cannot be blank", item.message
  end

  def test_status_should_be_set
    import = generate_import_with_mapping
    import.mapping['status'] = '14'
    import.save!

    issues = new_records(Issue, 3) {import.run}
    assert_equal ['New', 'New', 'Assigned'], issues.map {|x| x.status.name}
  end

  def test_parent_should_be_set
    import = generate_import_with_mapping
    import.mapping['parent_issue_id'] = '5'
    import.save!

    issues = new_records(Issue, 3) {import.run}
    assert_nil issues[0].parent
    assert_equal issues[0].id, issues[1].parent_id
    assert_equal 2, issues[2].parent_id
  end

  def test_import_utf8_with_bom
    import = generate_import_with_mapping('import_issues_utf8_with_bom.csv')
    import.settings['encoding'] = 'UTF-8'
    import.save

    issues = new_records(Issue, 3) {import.run}
    assert_equal 3, issues.count
  end

  def test_backward_and_forward_reference_to_parent_should_work
    import = generate_import('import_subtasks.csv')
    import.settings = {
      'separator' => ";", 'wrapper' => '"', 'encoding' => "UTF-8",
      'mapping' => {'project_id' => '1', 'tracker' => '1', 'subject' => '2', 'parent_issue_id' => '3'}
    }
    import.save!

    root, child1, grandchild, child2 = new_records(Issue, 4) {import.run}
    assert_equal root, child1.parent
    assert_equal child2, grandchild.parent
  end

  def test_references_with_unique_id
    import = generate_import_with_mapping('import_subtasks_with_unique_id.csv')
    import.settings['mapping'] = {'project_id' => '1', 'unique_id' => '0', 'tracker' => '1', 'subject' => '2', 'parent_issue_id' => '3', 'relation_follows' => '4'}
    import.save!

    red4, red3, red2, red1, blue1, blue2, blue3, blue4, green = new_records(Issue, 9) {import.run}

    # future references
    assert_equal red1, red2.parent
    assert_equal red3, red4.parent

    assert IssueRelation.where('issue_from_id' => red2.id, 'issue_to_id' => red3.id, 'delay' => 1, 'relation_type' => 'precedes').present?

    # past references
    assert_equal blue1, blue2.parent
    assert_equal blue3, blue4.parent

    assert IssueRelation.where('issue_from_id' => blue2.id, 'issue_to_id' => blue3.id, 'delay' => 1, 'relation_type' => 'precedes').present?

    assert_equal issues(:issues_001), green.parent
    assert IssueRelation.where('issue_from_id' => issues(:issues_002).id, 'issue_to_id' => green.id, 'delay' => 3, 'relation_type' => 'precedes').present?
  end

  def test_follow_relation
    import = generate_import_with_mapping('import_subtasks.csv')
    import.settings['mapping'] = {'project_id' => '1', 'tracker' => '1', 'subject' => '2', 'relation_relates' => '4'}
    import.save!

    one, one_one, one_two_one, one_two = new_records(Issue, 4) {import.run}
    assert_equal 2, one.relations.count
    assert one.relations.all? {|r| r.relation_type == 'relates'}
    assert one.relations.any? {|r| r.other_issue(one) == one_one}
    assert one.relations.any? {|r| r.other_issue(one) == one_two}

    assert_equal 2, one_one.relations.count
    assert one_one.relations.all? {|r| r.relation_type == 'relates'}
    assert one_one.relations.any? {|r| r.other_issue(one_one) == one}
    assert one_one.relations.any? {|r| r.other_issue(one_one) == one_two}

    assert_equal 3, one_two.relations.count
    assert one_two.relations.all? {|r| r.relation_type == 'relates'}
    assert one_two.relations.any? {|r| r.other_issue(one_two) == one}
    assert one_two.relations.any? {|r| r.other_issue(one_two) == one_one}
    assert one_two.relations.any? {|r| r.other_issue(one_two) == one_two_one}

    assert_equal 1, one_two_one.relations.count
    assert one_two_one.relations.all? {|r| r.relation_type == 'relates'}
    assert one_two_one.relations.any? {|r| r.other_issue(one_two_one) == one_two}
  end

  def test_delayed_relation
    import = generate_import_with_mapping('import_subtasks.csv')
    import.settings['mapping'] = {'project_id' => '1', 'tracker' => '1', 'subject' => '2', 'relation_precedes' => '5'}
    import.save!

    one, one_one, one_two_one, one_two = new_records(Issue, 4) {import.run}

    assert_equal 2, one.relations_to.count
    assert one.relations_to.all? {|r| r.relation_type == 'precedes'}
    assert one.relations_to.any? {|r| r.issue_from == one_one && r.delay == 2}
    assert one.relations_to.any? {|r| r.issue_from == one_two && r.delay == 1}

    assert_equal 1, one_one.relations_from.count
    assert one_one.relations_from.all? {|r| r.relation_type == 'precedes'}
    assert one_one.relations_from.any? {|r| r.issue_to == one && r.delay == 2}

    assert_equal 1, one_two.relations_to.count
    assert one_two.relations_to.all? {|r| r.relation_type == 'precedes'}
    assert one_two.relations_to.any? {|r| r.issue_from == one_two_one && r.delay == -1}

    assert_equal 1, one_two.relations_from.count
    assert one_two.relations_from.all? {|r| r.relation_type == 'precedes'}
    assert one_two.relations_from.any? {|r| r.issue_to == one && r.delay == 1}

    assert_equal 1, one_two_one.relations_from.count
    assert one_two_one.relations_from.all? {|r| r.relation_type == 'precedes'}
    assert one_two_one.relations_from.any? {|r| r.issue_to == one_two && r.delay == -1}
  end

  def test_parent_and_follows_relation
    import = generate_import_with_mapping('import_subtasks_with_relations.csv')
    import.settings['mapping'] = {
      'project_id'       => '1',
      'tracker'          => '1',

      'subject'          => '2',
      'start_date'       => '3',
      'due_date'         => '4',
      'parent_issue_id'  => '5',
      'relation_follows' => '6'
    }
    import.save!

    second, first, parent, third = assert_difference('IssueRelation.count', 2) {new_records(Issue, 4) {import.run}}

    # Parent relations
    assert_equal parent, first.parent
    assert_equal parent, second.parent
    assert_equal parent, third.parent

    # Issue relations
    assert IssueRelation.where(
      :issue_from_id => first.id,
      :issue_to_id   => second.id,
      :relation_type => 'precedes',
      :delay         => 1).present?

    assert IssueRelation.where(
      :issue_from_id => second.id,
      :issue_to_id   => third.id,
      :relation_type => 'precedes',
      :delay         => 1).present?

    # Checking dates, because they might act weird, when relations are added
    assert_equal Date.new(2020, 1, 1), parent.start_date
    assert_equal Date.new(2020, 2, 3), parent.due_date

    assert_equal Date.new(2020, 1, 1), first.start_date
    assert_equal Date.new(2020, 1, 10), first.due_date

    assert_equal Date.new(2020, 1, 14), second.start_date
    assert_equal Date.new(2020, 1, 21), second.due_date

    assert_equal Date.new(2020, 1, 23), third.start_date
    assert_equal Date.new(2020, 2, 3), third.due_date
  end

  def test_import_with_relations_and_invalid_issue_should_not_fail
    import = generate_import_with_mapping('import_issues_with_relation_and_invalid_issues.csv')
    import.settings['mapping'] = {
      'project_id' => '1',

      'tracker'          => '1',
      'subject'          => '2',
      'status'           => '3',
      'relation_relates' => '4',
    }
    import.save!

    first, second, third, fourth = new_records(Issue, 4) {import.run}

    assert_equal 1, import.unsaved_items.count
    item = import.unsaved_items.first
    assert_include "Subject cannot be blank", item.message

    assert_equal 1, first.relations_from.count
    assert_equal 1, second.relations_to.count
  end

  def test_assignee_should_be_set
    import = generate_import_with_mapping
    import.mapping['assigned_to'] = '11'
    import.save!

    issues = new_records(Issue, 3) {import.run}
    assert_equal [User.find(3), nil, nil], issues.map(&:assigned_to)
  end

  def test_user_custom_field_should_be_set
    field = IssueCustomField.generate!(:field_format => 'user', :is_for_all => true, :trackers => Tracker.all)
    import = generate_import_with_mapping
    import.mapping["cf_#{field.id}"] = '11'
    import.save!

    issues = new_records(Issue, 3) {import.run}
    assert_equal '3', issues.first.custom_field_value(field)
  end

  def test_list_custom_field_should_be_set
    field = CustomField.find(1)
    field.tracker_ids = Tracker.ids
    field.save!
    import = generate_import_with_mapping
    import.mapping["cf_1"] = '8'
    import.save!

    issues = new_records(Issue, 3) {import.run}
    assert_equal 'PostgreSQL', issues[0].custom_field_value(1)
    assert_equal 'MySQL', issues[1].custom_field_value(1)
    assert_equal '', issues.third.custom_field_value(1)
  end

  def test_multiple_list_custom_field_should_be_set
    field = CustomField.find(1)
    field.tracker_ids = Tracker.ids
    field.multiple = true
    field.save!
    import = generate_import_with_mapping
    import.mapping["cf_1"] = '15'
    import.save!

    issues = new_records(Issue, 3) {import.run}
    assert_equal ['Oracle', 'PostgreSQL'], issues[0].custom_field_value(1).sort
    assert_equal ['MySQL'], issues[1].custom_field_value(1)
    assert_equal [''], issues.third.custom_field_value(1)
  end

  def test_is_private_should_be_set_based_on_user_locale
    import = generate_import_with_mapping
    import.mapping['is_private'] = '6'
    import.save!

    issues = new_records(Issue, 3) {import.run}
    assert_equal [false, true, false], issues.map(&:is_private)
  end

  def test_dates_should_be_parsed_using_date_format_setting
    field = IssueCustomField.generate!(:field_format => 'date', :is_for_all => true, :trackers => Tracker.all)
    import = generate_import_with_mapping('import_dates.csv')
    import.settings['date_format'] = Import::DATE_FORMATS[1]
    import.mapping.merge!('tracker' => 'value:1', 'subject' => '0', 'start_date' => '1', 'due_date' => '2', "cf_#{field.id}" => '3')
    import.save!

    issue = new_record(Issue) {import.run} # only 1 valid issue
    assert_equal "Valid dates", issue.subject
    assert_equal Date.parse('2015-07-10'), issue.start_date
    assert_equal Date.parse('2015-08-12'), issue.due_date
    assert_equal '2015-07-14', issue.custom_field_value(field)

    # Tests using other date formats
    import = generate_import_with_mapping('import_dates_ja.csv')
    import.settings['date_format'] = Import::DATE_FORMATS[3]
    import.mapping.merge!('tracker' => 'value:1', 'subject' => '0', 'start_date' => '1')
    import.save!

    issue = new_record(Issue) {import.run}
    assert_equal Date.parse('2019-05-28'), issue.start_date
  end

  def test_date_format_should_default_to_user_language
    user = User.generate!(:language => 'fr')
    import = Import.new
    import.user = user
    assert_nil import.settings['date_format']

    import.set_default_settings
    assert_equal '%d/%m/%Y', import.settings['date_format']
  end

  def test_run_should_remove_the_file
    import = generate_import_with_mapping
    file_path = import.filepath
    assert File.exist?(file_path)

    import.run
    assert !File.exist?(file_path)
  end

  def test_run_should_consider_project_shared_versions
    system_version = Version.generate!(:project_id => 2, :sharing => 'system', :name => '2.1')
    system_version.save!

    import = generate_import_with_mapping
    import.mapping['fixed_version'] = '9'
    import.save!

    issues = new_records(Issue, 3) {import.run}
    assert [nil, 3, system_version.id], issues.map(&:fixed_version_id)
  end

  def test_set_default_settings_with_project_id
    import = Import.new
    import.set_default_settings(:project_id => 3)

    assert_equal 3, import.mapping['project_id']
  end

  def test_set_default_settings_with_project_identifier
    import = Import.new
    import.set_default_settings(:project_id => 'ecookbook')

    assert_equal 1, import.mapping['project_id']
  end

  def test_set_default_settings_without_project_id
    import = Import.new
    import.set_default_settings

    assert_empty import.mapping
  end

  def test_set_default_settings_with_invalid_project_should_not_fail
    import = Import.new
    import.set_default_settings(:project_id => 'abc')

    assert_empty import.mapping
  end

  def test_set_default_settings_should_guess_encoding
    import = generate_import('import_iso8859-1.csv')
    user = User.generate!(:language => 'ja')
    import.user = user
    assert_equal 'CP932', lu(user, :general_csv_encoding)
    with_settings :repositories_encodings => 'UTF-8,ISO-8859-1' do
      import.set_default_settings
      guessed_encoding = import.settings['encoding']
      assert_equal 'ISO-8859-1', guessed_encoding
    end
    with_settings :repositories_encodings => 'UTF-8,iso8859-1' do
      import.set_default_settings
      guessed_encoding = import.settings['encoding']
      assert_equal 'ISO-8859-1', guessed_encoding
      assert_includes Setting::ENCODINGS, guessed_encoding
    end
  end

  def test_set_default_settings_should_use_general_csv_encoding_when_cannnot_guess_encoding
    import = generate_import('import_iso8859-1.csv')
    user = User.generate!(:language => 'ja')
    import.user = user
    with_settings :repositories_encodings => 'UTF-8' do
      import.set_default_settings
      guessed_encoding = import.settings['encoding']
      assert_equal 'CP932', lu(user, :general_csv_encoding)
      assert_equal 'CP932', guessed_encoding
    end
  end

  def test_encoding_guessing_respects_multibyte_boundaries
    # Reading a specified number of bytes from the beginning of this file
    # may stop in the middle of a multi-byte character, which can lead to
    # an invalid UTF-8 string.
    test_file = 'mbcs-multiline-text.txt'
    chunk = File.read(Rails.root.join('test', 'fixtures', 'files', test_file), 4096)
    chunk.force_encoding('UTF-8') # => "...😃😄😅\xF0\x9F"
    assert_not chunk.valid_encoding?

    import = generate_import(test_file)
    with_settings :repositories_encodings => 'UTF-8,ISO-8859-1' do
      import.set_default_settings
      guessed_encoding = import.settings['encoding']
      assert_equal 'UTF-8', guessed_encoding
    end
  end

  def test_set_default_settings_should_detect_field_wrapper
    to_test = {
      'import_issues.csv' => '"',
      'import_issues_single_quotation.csv' => "'",
      # Use '"' as a wrapper for CSV file with no wrappers
      'import_dates.csv' => '"',
    }

    to_test.each do |file, expected|
      import = generate_import(file)
      import.set_default_settings
      assert_equal expected, import.settings['wrapper']
    end
  end
end
