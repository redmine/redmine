# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

require File.expand_path('../../../test_helper', __FILE__)

class Redmine::ApiTest::IssuesTest < Redmine::ApiTest::Base
  fixtures :projects,
    :users,
    :roles,
    :members,
    :member_roles,
    :issues,
    :issue_statuses,
    :issue_relations,
    :versions,
    :trackers,
    :projects_trackers,
    :issue_categories,
    :enabled_modules,
    :enumerations,
    :attachments,
    :workflows,
    :custom_fields,
    :custom_values,
    :custom_fields_projects,
    :custom_fields_trackers,
    :time_entries,
    :journals,
    :journal_details,
    :queries,
    :attachments

  test "GET /issues.xml should contain metadata" do
    get '/issues.xml'
    assert_select 'issues[type=array][total_count=?][limit="25"][offset="0"]',
      assigns(:issue_count).to_s
  end

  test "GET /issues.xml with nometa param should not contain metadata" do
    get '/issues.xml?nometa=1'
    assert_select 'issues[type=array]:not([total_count]):not([limit]):not([offset])'
  end

  test "GET /issues.xml with nometa header should not contain metadata" do
    get '/issues.xml', {}, {'X-Redmine-Nometa' => '1'}
    assert_select 'issues[type=array]:not([total_count]):not([limit]):not([offset])'
  end

  test "GET /issues.xml with offset and limit" do
    get '/issues.xml?offset=2&limit=3'

    assert_equal 3, assigns(:limit)
    assert_equal 2, assigns(:offset)
    assert_select 'issues issue', 3
  end

  test "GET /issues.xml with relations" do
    get '/issues.xml?include=relations'

    assert_response :success
    assert_equal 'application/xml', @response.content_type

    assert_select 'issue id', :text => '3' do
      assert_select '~ relations relation', 1
      assert_select '~ relations relation[id="2"][issue_id="2"][issue_to_id="3"][relation_type=relates]'
    end

    assert_select 'issue id', :text => '1' do
      assert_select '~ relations'
      assert_select '~ relations relation', 0
    end
  end

  test "GET /issues.xml with invalid query params" do
    get '/issues.xml', {:f => ['start_date'], :op => {:start_date => '='}}

    assert_response :unprocessable_entity
    assert_equal 'application/xml', @response.content_type
    assert_select 'errors error', :text => "Start date cannot be blank"
  end

  test "GET /issues.xml with custom field filter" do
    get '/issues.xml',
      {:set_filter => 1, :f => ['cf_1'], :op => {:cf_1 => '='}, :v => {:cf_1 => ['MySQL']}}

    expected_ids = Issue.visible.
        joins(:custom_values).
        where(:custom_values => {:custom_field_id => 1, :value => 'MySQL'}).map(&:id)
    assert expected_ids.any?

    assert_select 'issues > issue > id', :count => expected_ids.count do |ids|
       ids.each { |id| assert expected_ids.delete(id.children.first.content.to_i) }
    end
  end

  test "GET /issues.xml with custom field filter (shorthand method)" do
    get '/issues.xml', {:cf_1 => 'MySQL'}

    expected_ids = Issue.visible.
        joins(:custom_values).
        where(:custom_values => {:custom_field_id => 1, :value => 'MySQL'}).map(&:id)
    assert expected_ids.any?

    assert_select 'issues > issue > id', :count => expected_ids.count do |ids|
      ids.each { |id| assert expected_ids.delete(id.children.first.content.to_i) }
    end
  end

  def test_index_should_include_issue_attributes
    get '/issues.xml'
    assert_select 'issues>issue>is_private', :text => 'false'
  end

  def test_index_should_allow_timestamp_filtering
    Issue.delete_all
    Issue.generate!(:subject => '1').update_column(:updated_on, Time.parse("2014-01-02T10:25:00Z"))
    Issue.generate!(:subject => '2').update_column(:updated_on, Time.parse("2014-01-02T12:13:00Z"))

    get '/issues.xml',
      {:set_filter => 1, :f => ['updated_on'], :op => {:updated_on => '<='},
       :v => {:updated_on => ['2014-01-02T12:00:00Z']}}
    assert_select 'issues>issue', :count => 1
    assert_select 'issues>issue>subject', :text => '1'

    get '/issues.xml',
      {:set_filter => 1, :f => ['updated_on'], :op => {:updated_on => '>='},
       :v => {:updated_on => ['2014-01-02T12:00:00Z']}}
    assert_select 'issues>issue', :count => 1
    assert_select 'issues>issue>subject', :text => '2'

    get '/issues.xml',
      {:set_filter => 1, :f => ['updated_on'], :op => {:updated_on => '>='},
       :v => {:updated_on => ['2014-01-02T08:00:00Z']}}
    assert_select 'issues>issue', :count => 2
  end

  test "GET /issues.xml with filter" do
    get '/issues.xml?status_id=5'

    expected_ids = Issue.visible.where(:status_id => 5).map(&:id)
    assert expected_ids.any?

    assert_select 'issues > issue > id', :count => expected_ids.count do |ids|
       ids.each { |id| assert expected_ids.delete(id.children.first.content.to_i) }
    end
  end

  test "GET /issues.json with filter" do
    get '/issues.json?status_id=5'

    json = ActiveSupport::JSON.decode(response.body)
    status_ids_used = json['issues'].collect {|j| j['status']['id'] }
    assert_equal 3, status_ids_used.length
    assert status_ids_used.all? {|id| id == 5 }
  end

  test "GET /issues/:id.xml with journals" do
    Journal.find(2).update_attribute(:private_notes, true)

    get '/issues/1.xml?include=journals', {}, credentials('jsmith')

    assert_select 'issue journals[type=array]' do
      assert_select 'journal[id="1"]' do
        assert_select 'private_notes', :text => 'false'
        assert_select 'details[type=array]' do
          assert_select 'detail[name=status_id]' do
            assert_select 'old_value', :text => '1'
            assert_select 'new_value', :text => '2'
          end
        end
      end
      assert_select 'journal[id="2"]' do
        assert_select 'private_notes', :text => 'true'
        assert_select 'details[type=array]'
      end
    end
  end

  test "GET /issues/:id.xml with journals should format timestamps in ISO 8601" do
    get '/issues/1.xml?include=journals'

    iso_date = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/
    assert_select 'issue>created_on', :text => iso_date
    assert_select 'issue>updated_on', :text => iso_date
    assert_select 'issue journal>created_on', :text => iso_date
  end

  test "GET /issues/:id.xml with custom fields" do
    get '/issues/3.xml'

    assert_select 'issue custom_fields[type=array]' do
      assert_select 'custom_field[id="1"]' do
        assert_select 'value', :text => 'MySQL'
      end
    end
    assert_nothing_raised do
      Hash.from_xml(response.body).to_xml
    end
  end

  test "GET /issues/:id.xml with multi custom fields" do
    field = CustomField.find(1)
    field.update_attribute :multiple, true
    issue = Issue.find(3)
    issue.custom_field_values = {1 => ['MySQL', 'Oracle']}
    issue.save!

    get '/issues/3.xml'
    assert_response :success

    assert_select 'issue custom_fields[type=array]' do
      assert_select 'custom_field[id="1"]' do
        assert_select 'value[type=array] value', 2
      end
    end
    xml = Hash.from_xml(response.body)
    custom_fields = xml['issue']['custom_fields']
    assert_kind_of Array, custom_fields
    field = custom_fields.detect {|f| f['id'] == '1'}
    assert_kind_of Hash, field
    assert_equal ['MySQL', 'Oracle'], field['value'].sort
  end

  test "GET /issues/:id.json with multi custom fields" do
    field = CustomField.find(1)
    field.update_attribute :multiple, true
    issue = Issue.find(3)
    issue.custom_field_values = {1 => ['MySQL', 'Oracle']}
    issue.save!

    get '/issues/3.json'
    assert_response :success

    json = ActiveSupport::JSON.decode(response.body)
    custom_fields = json['issue']['custom_fields']
    assert_kind_of Array, custom_fields
    field = custom_fields.detect {|f| f['id'] == 1}
    assert_kind_of Hash, field
    assert_equal ['MySQL', 'Oracle'], field['value'].sort
  end

  test "GET /issues/:id.xml with empty value for multi custom field" do
    field = CustomField.find(1)
    field.update_attribute :multiple, true
    issue = Issue.find(3)
    issue.custom_field_values = {1 => ['']}
    issue.save!

    get '/issues/3.xml'

    assert_select 'issue custom_fields[type=array]' do
      assert_select 'custom_field[id="1"]' do
        assert_select 'value[type=array]:empty'
      end
    end
    xml = Hash.from_xml(response.body)
    custom_fields = xml['issue']['custom_fields']
    assert_kind_of Array, custom_fields
    field = custom_fields.detect {|f| f['id'] == '1'}
    assert_kind_of Hash, field
    assert_equal [], field['value']
  end

  test "GET /issues/:id.json with empty value for multi custom field" do
    field = CustomField.find(1)
    field.update_attribute :multiple, true
    issue = Issue.find(3)
    issue.custom_field_values = {1 => ['']}
    issue.save!

    get '/issues/3.json'
    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    custom_fields = json['issue']['custom_fields']
    assert_kind_of Array, custom_fields
    field = custom_fields.detect {|f| f['id'] == 1}
    assert_kind_of Hash, field
    assert_equal [], field['value'].sort
  end

  test "GET /issues/:id.xml with attachments" do
    get '/issues/3.xml?include=attachments'

    assert_select 'issue attachments[type=array]' do
      assert_select 'attachment', 4
      assert_select 'attachment id', :text => '1' do
        assert_select '~ filename', :text => 'error281.txt'
        assert_select '~ content_url', :text => 'http://www.example.com/attachments/download/1/error281.txt'
      end
    end
  end

  test "GET /issues/:id.xml with subtasks" do
    issue = Issue.generate_with_descendants!(:project_id => 1)
    get "/issues/#{issue.id}.xml?include=children"

    assert_select 'issue id', :text => issue.id.to_s do
      assert_select '~ children[type=array] > issue', 2
      assert_select '~ children[type=array] > issue > children', 1
    end
  end

  test "GET /issues/:id.json with subtasks" do
    issue = Issue.generate_with_descendants!(:project_id => 1)
    get "/issues/#{issue.id}.json?include=children"

    json = ActiveSupport::JSON.decode(response.body)
    assert_equal 2, json['issue']['children'].size
    assert_equal 1, json['issue']['children'].select {|child| child.key?('children')}.size
  end

  def test_show_should_include_issue_attributes
    get '/issues/1.xml'
    assert_select 'issue>is_private', :text => 'false'
  end

  test "GET /issues/:id.xml?include=watchers should include watchers" do
    Watcher.create!(:user_id => 3, :watchable => Issue.find(1))

    get '/issues/1.xml?include=watchers', {}, credentials('jsmith')

    assert_response :ok
    assert_equal 'application/xml', response.content_type
    assert_select 'issue' do
      assert_select 'watchers', Issue.find(1).watchers.count
      assert_select 'watchers' do
        assert_select 'user[id="3"]'
      end
    end
  end

  test "GET /issues/:id.xml should not disclose associated changesets from projects the user has no access to" do
    project = Project.generate!(:is_public => false)
    repository = Repository::Subversion.create!(:project => project, :url => "svn://localhost")
    Issue.find(1).changesets << Changeset.generate!(:repository => repository)
    assert Issue.find(1).changesets.any?

    get '/issues/1.xml?include=changesets', {}, credentials('jsmith')

    # the user jsmith has no permission to view the associated changeset
    assert_select 'issue changesets[type=array]' do
      assert_select 'changeset', 0
    end
  end

  test "GET /issues/:id.xml should contains total_estimated_hours and total_spent_hours" do
    parent = Issue.find(3)
    child = Issue.generate!(:parent_issue_id => parent.id, :estimated_hours => 3.0)
    TimeEntry.create!(:project => child.project, :issue => child, :user => child.author, :spent_on => child.author.today,
                      :hours => '2.5', :comments => '', :activity_id => TimeEntryActivity.first.id)
    get '/issues/3.xml'

    assert_equal 'application/xml', response.content_type
    assert_select 'issue' do
      assert_select 'estimated_hours',       parent.estimated_hours.to_s
      assert_select 'total_estimated_hours', (parent.estimated_hours.to_f + 3.0).to_s
      assert_select 'spent_hours',           parent.spent_hours.to_s
      assert_select 'total_spent_hours',     (parent.spent_hours.to_f + 2.5).to_s
    end
  end

  test "GET /issues/:id.xml should contains total_estimated_hours, and should not contains spent_hours and total_spent_hours when permission does not exists" do
    parent = Issue.find(3)
    child = Issue.generate!(:parent_issue_id => parent.id, :estimated_hours => 3.0)
    # remove permission!
    Role.anonymous.remove_permission! :view_time_entries
    #Role.all.each { |role| role.remove_permission! :view_time_entries }
    get '/issues/3.xml'

    assert_equal 'application/xml', response.content_type
    assert_select 'issue' do
      assert_select 'estimated_hours',       parent.estimated_hours.to_s
      assert_select 'total_estimated_hours', (parent.estimated_hours.to_f + 3.0).to_s
      assert_select 'spent_hours',           false
      assert_select 'total_spent_hours',     false
    end
  end

  test "GET /issues/:id.json should contains total_estimated_hours and total_spent_hours" do
    parent = Issue.find(3)
    child = Issue.generate!(:parent_issue_id => parent.id, :estimated_hours => 3.0)
    TimeEntry.create!(:project => child.project, :issue => child, :user => child.author, :spent_on => child.author.today,
                      :hours => '2.5', :comments => '', :activity_id => TimeEntryActivity.first.id)
    get '/issues/3.json'

    assert_equal 'application/json', response.content_type
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal parent.estimated_hours, json['issue']['estimated_hours']
    assert_equal (parent.estimated_hours.to_f + 3.0), json['issue']['total_estimated_hours']
    assert_equal parent.spent_hours, json['issue']['spent_hours']
    assert_equal (parent.spent_hours.to_f + 2.5), json['issue']['total_spent_hours']
  end

  test "GET /issues/:id.json should contains total_estimated_hours, and should not contains spent_hours and total_spent_hours when permission does not exists" do
    parent = Issue.find(3)
    child = Issue.generate!(:parent_issue_id => parent.id, :estimated_hours => 3.0)
    # remove permission!
    Role.anonymous.remove_permission! :view_time_entries
    #Role.all.each { |role| role.remove_permission! :view_time_entries }
    get '/issues/3.json'

    assert_equal 'application/json', response.content_type
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal parent.estimated_hours, json['issue']['estimated_hours']
    assert_equal (parent.estimated_hours.to_f + 3.0), json['issue']['total_estimated_hours']
    assert_equal nil, json['issue']['spent_hours']
    assert_equal nil, json['issue']['total_spent_hours']
  end

  test "POST /issues.xml should create an issue with the attributes" do

payload = <<-XML
<?xml version="1.0" encoding="UTF-8" ?>
<issue>
  <project_id>1</project_id>
  <tracker_id>2</tracker_id>
  <status_id>3</status_id>
  <subject>API test</subject>
</issue>
XML

    assert_difference('Issue.count') do
      post '/issues.xml', payload, {"CONTENT_TYPE" => 'application/xml'}.merge(credentials('jsmith'))
    end
    issue = Issue.order('id DESC').first
    assert_equal 1, issue.project_id
    assert_equal 2, issue.tracker_id
    assert_equal 3, issue.status_id
    assert_equal 'API test', issue.subject

    assert_response :created
    assert_equal 'application/xml', @response.content_type
    assert_select 'issue > id', :text => issue.id.to_s
  end

  test "POST /issues.xml with watcher_user_ids should create issue with watchers" do
    assert_difference('Issue.count') do
      post '/issues.xml',
           {:issue => {:project_id => 1, :subject => 'Watchers',
            :tracker_id => 2, :status_id => 3, :watcher_user_ids => [3, 1]}}, credentials('jsmith')
      assert_response :created
    end
    issue = Issue.order('id desc').first
    assert_equal 2, issue.watchers.size
    assert_equal [1, 3], issue.watcher_user_ids.sort
  end

  test "POST /issues.xml with failure should return errors" do
    assert_no_difference('Issue.count') do
      post '/issues.xml', {:issue => {:project_id => 1}}, credentials('jsmith')
    end

    assert_select 'errors error', :text => "Subject cannot be blank"
  end

  test "POST /issues.json should create an issue with the attributes" do

payload = <<-JSON
{
  "issue": {
    "project_id": "1",
    "tracker_id": "2",
    "status_id": "3",
    "subject": "API test"
  }
}
JSON

    assert_difference('Issue.count') do
      post '/issues.json', payload, {"CONTENT_TYPE" => 'application/json'}.merge(credentials('jsmith'))
    end

    issue = Issue.order('id DESC').first
    assert_equal 1, issue.project_id
    assert_equal 2, issue.tracker_id
    assert_equal 3, issue.status_id
    assert_equal 'API test', issue.subject
  end

  test "POST /issues.json without tracker_id should accept custom fields" do
    field = IssueCustomField.generate!(
      :field_format => 'list',
      :multiple => true,
      :possible_values => ["V1", "V2", "V3"],
      :default_value => "V2",
      :is_for_all => true,
      :trackers => Tracker.all.to_a
    )

payload = <<-JSON
{
  "issue": {
    "project_id": "1",
    "subject": "Multivalued custom field",
    "custom_field_values":{"#{field.id}":["V1","V3"]}
  }
}
JSON

    assert_difference('Issue.count') do
      post '/issues.json', payload, {"CONTENT_TYPE" => 'application/json'}.merge(credentials('jsmith'))
    end

    assert_response :created
    issue = Issue.order('id DESC').first
    assert_equal ["V1", "V3"], issue.custom_field_value(field).sort
  end

  test "POST /issues.json with omitted custom field should set default value" do
    field = IssueCustomField.generate!(:default_value => "Default")

    issue = new_record(Issue) do
      post '/issues.json',
        {:issue => {:project_id => 1, :subject => 'API', :custom_field_values => {}}},
        credentials('jsmith')
    end
    assert_equal "Default", issue.custom_field_value(field)
  end

  test "POST /issues.json with custom field set to blank should not set default value" do
    field = IssueCustomField.generate!(:default_value => "Default")

    issue = new_record(Issue) do
      post '/issues.json',
        {:issue => {:project_id => 1, :subject => 'API', :custom_field_values => {field.id.to_s => ""}}},
        credentials('jsmith')
    end
    assert_equal "", issue.custom_field_value(field)
  end

  test "POST /issues.json with failure should return errors" do
    assert_no_difference('Issue.count') do
      post '/issues.json', {:issue => {:project_id => 1}}, credentials('jsmith')
    end

    json = ActiveSupport::JSON.decode(response.body)
    assert json['errors'].include?("Subject cannot be blank")
  end

  test "POST /issues.json with invalid project_id should respond with 422" do
    post '/issues.json', {:issue => {:project_id => 999, :subject => "API"}}, credentials('jsmith')
    assert_response 422
  end

  test "PUT /issues/:id.xml" do
    assert_difference('Journal.count') do
      put '/issues/6.xml',
        {:issue => {:subject => 'API update', :notes => 'A new note'}},
        credentials('jsmith')
    end

    issue = Issue.find(6)
    assert_equal "API update", issue.subject
    journal = Journal.last
    assert_equal "A new note", journal.notes
  end

  test "PUT /issues/:id.xml with custom fields" do
    put '/issues/3.xml',
      {:issue => {:custom_fields => [
        {'id' => '1', 'value' => 'PostgreSQL' },
        {'id' => '2', 'value' => '150'}
        ]}},
      credentials('jsmith')

    issue = Issue.find(3)
    assert_equal '150', issue.custom_value_for(2).value
    assert_equal 'PostgreSQL', issue.custom_value_for(1).value
  end

  test "PUT /issues/:id.xml with multi custom fields" do
    field = CustomField.find(1)
    field.update_attribute :multiple, true

    put '/issues/3.xml',
      {:issue => {:custom_fields => [
        {'id' => '1', 'value' => ['MySQL', 'PostgreSQL'] },
        {'id' => '2', 'value' => '150'}
        ]}},
      credentials('jsmith')

    issue = Issue.find(3)
    assert_equal '150', issue.custom_value_for(2).value
    assert_equal ['MySQL', 'PostgreSQL'], issue.custom_field_value(1).sort
  end

  test "PUT /issues/:id.xml with project change" do
    put '/issues/3.xml',
      {:issue => {:project_id => 2, :subject => 'Project changed'}},
      credentials('jsmith')

    issue = Issue.find(3)
    assert_equal 2, issue.project_id
    assert_equal 'Project changed', issue.subject
  end

  test "PUT /issues/:id.xml with notes only" do
    assert_difference('Journal.count') do
      put '/issues/6.xml',
        {:issue => {:notes => 'Notes only'}},
        credentials('jsmith')
    end

    journal = Journal.last
    assert_equal "Notes only", journal.notes
  end

  test "PUT /issues/:id.json with omitted custom field should not change blank value to default value" do
    field = IssueCustomField.generate!(:default_value => "Default")
    issue = Issue.generate!(:project_id => 1, :tracker_id => 1, :custom_field_values => {field.id.to_s => ""})
    assert_equal "", issue.reload.custom_field_value(field)

    assert_difference('Journal.count') do
      put "/issues/#{issue.id}.json",
        {:issue => {:custom_field_values => {}, :notes => 'API'}},
        credentials('jsmith')
    end

    assert_equal "", issue.reload.custom_field_value(field)
  end

  test "PUT /issues/:id.json with custom field set to blank should not change blank value to default value" do
    field = IssueCustomField.generate!(:default_value => "Default")
    issue = Issue.generate!(:project_id => 1, :tracker_id => 1, :custom_field_values => {field.id.to_s => ""})
    assert_equal "", issue.reload.custom_field_value(field)

    assert_difference('Journal.count') do
      put "/issues/#{issue.id}.json",
        {:issue => {:custom_field_values => {field.id.to_s => ""}, :notes => 'API'}},
        credentials('jsmith')
    end

    assert_equal "", issue.reload.custom_field_value(field)
  end

  test "PUT /issues/:id.json with tracker change and omitted custom field specific to that tracker should set default value" do
    field = IssueCustomField.generate!(:default_value => "Default", :tracker_ids => [2])
    issue = Issue.generate!(:project_id => 1, :tracker_id => 1)

    assert_difference('Journal.count') do
      put "/issues/#{issue.id}.json",
        {:issue => {:tracker_id => 2, :custom_field_values => {}, :notes => 'API'}},
        credentials('jsmith')
    end

    assert_equal 2, issue.reload.tracker_id
    assert_equal "Default", issue.reload.custom_field_value(field)
  end

  test "PUT /issues/:id.json with tracker change and custom field specific to that tracker set to blank should not set default value" do
    field = IssueCustomField.generate!(:default_value => "Default", :tracker_ids => [2])
    issue = Issue.generate!(:project_id => 1, :tracker_id => 1)

    assert_difference('Journal.count') do
      put "/issues/#{issue.id}.json",
        {:issue => {:tracker_id => 2, :custom_field_values => {field.id.to_s => ""}, :notes => 'API'}},
        credentials('jsmith')
    end

    assert_equal 2, issue.reload.tracker_id
    assert_equal "", issue.reload.custom_field_value(field)
  end

  test "PUT /issues/:id.xml with failed update" do
    put '/issues/6.xml', {:issue => {:subject => ''}}, credentials('jsmith')

    assert_response :unprocessable_entity
    assert_select 'errors error', :text => "Subject cannot be blank"
  end

  test "PUT /issues/:id.json" do
    assert_difference('Journal.count') do
      put '/issues/6.json',
        {:issue => {:subject => 'API update', :notes => 'A new note'}},
        credentials('jsmith')

      assert_response :ok
      assert_equal '', response.body
    end

    issue = Issue.find(6)
    assert_equal "API update", issue.subject
    journal = Journal.last
    assert_equal "A new note", journal.notes
  end

  test "PUT /issues/:id.json with failed update" do
    put '/issues/6.json', {:issue => {:subject => ''}}, credentials('jsmith')

    assert_response :unprocessable_entity
    json = ActiveSupport::JSON.decode(response.body)
    assert json['errors'].include?("Subject cannot be blank")
  end

  test "DELETE /issues/:id.xml" do
    assert_difference('Issue.count', -1) do
      delete '/issues/6.xml', {}, credentials('jsmith')

      assert_response :ok
      assert_equal '', response.body
    end
    assert_nil Issue.find_by_id(6)
  end

  test "DELETE /issues/:id.json" do
    assert_difference('Issue.count', -1) do
      delete '/issues/6.json', {}, credentials('jsmith')

      assert_response :ok
      assert_equal '', response.body
    end
    assert_nil Issue.find_by_id(6)
  end

  test "POST /issues/:id/watchers.xml should add watcher" do
    assert_difference 'Watcher.count' do
      post '/issues/1/watchers.xml', {:user_id => 3}, credentials('jsmith')

      assert_response :ok
      assert_equal '', response.body
    end
    watcher = Watcher.order('id desc').first
    assert_equal Issue.find(1), watcher.watchable
    assert_equal User.find(3), watcher.user
  end

  test "DELETE /issues/:id/watchers/:user_id.xml should remove watcher" do
    Watcher.create!(:user_id => 3, :watchable => Issue.find(1))

    assert_difference 'Watcher.count', -1 do
      delete '/issues/1/watchers/3.xml', {}, credentials('jsmith')

      assert_response :ok
      assert_equal '', response.body
    end
    assert_equal false, Issue.find(1).watched_by?(User.find(3))
  end

  def test_create_issue_with_uploaded_file
    token = xml_upload('test_create_with_upload', credentials('jsmith'))
    attachment = Attachment.find_by_token(token)

    # create the issue with the upload's token
    assert_difference 'Issue.count' do
      post '/issues.xml',
           {:issue => {:project_id => 1, :subject => 'Uploaded file',
                       :uploads => [{:token => token, :filename => 'test.txt',
                                     :content_type => 'text/plain'}]}},
           credentials('jsmith')
      assert_response :created
    end
    issue = Issue.order('id DESC').first
    assert_equal 1, issue.attachments.count
    assert_equal attachment, issue.attachments.first

    attachment.reload
    assert_equal 'test.txt', attachment.filename
    assert_equal 'text/plain', attachment.content_type
    assert_equal 'test_create_with_upload'.size, attachment.filesize
    assert_equal 2, attachment.author_id

    # get the issue with its attachments
    get "/issues/#{issue.id}.xml", :include => 'attachments'
    assert_response :success
    xml = Hash.from_xml(response.body)
    attachments = xml['issue']['attachments']
    assert_kind_of Array, attachments
    assert_equal 1, attachments.size
    url = attachments.first['content_url']
    assert_not_nil url

    # download the attachment
    get url
    assert_response :success
    assert_equal 'test_create_with_upload', response.body
  end

  def test_create_issue_with_multiple_uploaded_files_as_xml
    token1 = xml_upload('File content 1', credentials('jsmith'))
    token2 = xml_upload('File content 2', credentials('jsmith'))

    payload = <<-XML
<?xml version="1.0" encoding="UTF-8" ?>
<issue>
  <project_id>1</project_id>
  <tracker_id>1</tracker_id>
  <subject>Issue with multiple attachments</subject>
  <uploads type="array">
    <upload>
      <token>#{token1}</token>
      <filename>test1.txt</filename>
    </upload>
    <upload>
      <token>#{token2}</token>
      <filename>test1.txt</filename>
    </upload>
  </uploads>
</issue>
XML

    assert_difference 'Issue.count' do
      post '/issues.xml', payload, {"CONTENT_TYPE" => 'application/xml'}.merge(credentials('jsmith'))
      assert_response :created
    end
    issue = Issue.order('id DESC').first
    assert_equal 2, issue.attachments.count
  end

  def test_create_issue_with_multiple_uploaded_files_as_json
    token1 = json_upload('File content 1', credentials('jsmith'))
    token2 = json_upload('File content 2', credentials('jsmith'))

    payload = <<-JSON
{
  "issue": {
    "project_id": "1",
    "tracker_id": "1",
    "subject": "Issue with multiple attachments",
    "uploads": [
      {"token": "#{token1}", "filename": "test1.txt"},
      {"token": "#{token2}", "filename": "test2.txt"}
    ]
  }
}
JSON

    assert_difference 'Issue.count' do
      post '/issues.json', payload, {"CONTENT_TYPE" => 'application/json'}.merge(credentials('jsmith'))
      assert_response :created
    end
    issue = Issue.order('id DESC').first
    assert_equal 2, issue.attachments.count
  end

  def test_update_issue_with_uploaded_file
    token = xml_upload('test_upload_with_upload', credentials('jsmith'))
    attachment = Attachment.find_by_token(token)

    # update the issue with the upload's token
    assert_difference 'Journal.count' do
      put '/issues/1.xml',
          {:issue => {:notes => 'Attachment added',
                      :uploads => [{:token => token, :filename => 'test.txt',
                                    :content_type => 'text/plain'}]}},
          credentials('jsmith')
      assert_response :ok
      assert_equal '', @response.body
    end

    issue = Issue.find(1)
    assert_include attachment, issue.attachments
  end
end
