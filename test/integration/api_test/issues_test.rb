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

  def setup
    Setting.rest_api_enabled = '1'
  end

  context "/issues" do
    # Use a private project to make sure auth is really working and not just
    # only showing public issues.
    should_allow_api_authentication(:get, "/projects/private-child/issues.xml")

    should "contain metadata" do
      get '/issues.xml'

      assert_tag :tag => 'issues',
        :attributes => {
          :type => 'array',
          :total_count => assigns(:issue_count),
          :limit => 25,
          :offset => 0
        }
    end

    context "with offset and limit" do
      should "use the params" do
        get '/issues.xml?offset=2&limit=3'

        assert_equal 3, assigns(:limit)
        assert_equal 2, assigns(:offset)
        assert_tag :tag => 'issues', :children => {:count => 3, :only => {:tag => 'issue'}}
      end
    end

    context "with nometa param" do
      should "not contain metadata" do
        get '/issues.xml?nometa=1'

        assert_tag :tag => 'issues',
          :attributes => {
            :type => 'array',
            :total_count => nil,
            :limit => nil,
            :offset => nil
          }
      end
    end

    context "with nometa header" do
      should "not contain metadata" do
        get '/issues.xml', {}, {'X-Redmine-Nometa' => '1'}

        assert_tag :tag => 'issues',
          :attributes => {
            :type => 'array',
            :total_count => nil,
            :limit => nil,
            :offset => nil
          }
      end
    end

    context "with relations" do
      should "display relations" do
        get '/issues.xml?include=relations'

        assert_response :success
        assert_equal 'application/xml', @response.content_type
        assert_tag 'relations',
          :parent => {:tag => 'issue', :child => {:tag => 'id', :content => '3'}},
          :children => {:count => 1},
          :child => {
            :tag => 'relation',
            :attributes => {:id => '2', :issue_id => '2', :issue_to_id => '3',
                            :relation_type => 'relates'}
          }
        assert_tag 'relations',
          :parent => {:tag => 'issue', :child => {:tag => 'id', :content => '1'}},
          :children => {:count => 0}
      end
    end

    context "with invalid query params" do
      should "return errors" do
        get '/issues.xml', {:f => ['start_date'], :op => {:start_date => '='}}

        assert_response :unprocessable_entity
        assert_equal 'application/xml', @response.content_type
        assert_tag 'errors', :child => {:tag => 'error', :content => "Start date can't be blank"}
      end
    end

    context "with custom field filter" do
      should "show only issues with the custom field value" do
        get '/issues.xml',
            {:set_filter => 1, :f => ['cf_1'], :op => {:cf_1 => '='},
             :v => {:cf_1 => ['MySQL']}}
        expected_ids = Issue.visible.
            joins(:custom_values).
            where(:custom_values => {:custom_field_id => 1, :value => 'MySQL'}).map(&:id)
        assert_select 'issues > issue > id', :count => expected_ids.count do |ids|
           ids.each { |id| assert expected_ids.delete(id.children.first.content.to_i) }
        end
      end
    end

    context "with custom field filter (shorthand method)" do
      should "show only issues with the custom field value" do
        get '/issues.xml', { :cf_1 => 'MySQL' }

        expected_ids = Issue.visible.
            joins(:custom_values).
            where(:custom_values => {:custom_field_id => 1, :value => 'MySQL'}).map(&:id)

        assert_select 'issues > issue > id', :count => expected_ids.count do |ids|
          ids.each { |id| assert expected_ids.delete(id.children.first.content.to_i) }
        end
      end
    end
  end

  context "/index.json" do
    should_allow_api_authentication(:get, "/projects/private-child/issues.json")
  end

  context "/index.xml with filter" do
    should "show only issues with the status_id" do
      get '/issues.xml?status_id=5'

      expected_ids = Issue.visible.where(:status_id => 5).map(&:id)

      assert_select 'issues > issue > id', :count => expected_ids.count do |ids|
         ids.each { |id| assert expected_ids.delete(id.children.first.content.to_i) }
      end
    end
  end

  context "/index.json with filter" do
    should "show only issues with the status_id" do
      get '/issues.json?status_id=5'

      json = ActiveSupport::JSON.decode(response.body)
      status_ids_used = json['issues'].collect {|j| j['status']['id'] }
      assert_equal 3, status_ids_used.length
      assert status_ids_used.all? {|id| id == 5 }
    end

  end

  # Issue 6 is on a private project
  context "/issues/6.xml" do
    should_allow_api_authentication(:get, "/issues/6.xml")
  end

  context "/issues/6.json" do
    should_allow_api_authentication(:get, "/issues/6.json")
  end

  context "GET /issues/:id" do
    context "with journals" do
      context ".xml" do
        should "display journals" do
          get '/issues/1.xml?include=journals'

          assert_tag :tag => 'issue',
            :child => {
              :tag => 'journals',
              :attributes => { :type => 'array' },
              :child => {
                :tag => 'journal',
                :attributes => { :id => '1'},
                :child => {
                  :tag => 'details',
                  :attributes => { :type => 'array' },
                  :child => {
                    :tag => 'detail',
                    :attributes => { :name => 'status_id' },
                    :child => {
                      :tag => 'old_value',
                      :content => '1',
                      :sibling => {
                        :tag => 'new_value',
                        :content => '2'
                      }
                    }
                  }
                }
              }
            }
        end
      end
    end

    context "with custom fields" do
      context ".xml" do
        should "display custom fields" do
          get '/issues/3.xml'

          assert_tag :tag => 'issue',
            :child => {
              :tag => 'custom_fields',
              :attributes => { :type => 'array' },
              :child => {
                :tag => 'custom_field',
                :attributes => { :id => '1'},
                :child => {
                  :tag => 'value',
                  :content => 'MySQL'
                }
              }
            }

          assert_nothing_raised do
            Hash.from_xml(response.body).to_xml
          end
        end
      end
    end

    context "with multi custom fields" do
      setup do
        field = CustomField.find(1)
        field.update_attribute :multiple, true
        issue = Issue.find(3)
        issue.custom_field_values = {1 => ['MySQL', 'Oracle']}
        issue.save!
      end

      context ".xml" do
        should "display custom fields" do
          get '/issues/3.xml'
          assert_response :success
          assert_tag :tag => 'issue',
            :child => {
              :tag => 'custom_fields',
              :attributes => { :type => 'array' },
              :child => {
                :tag => 'custom_field',
                :attributes => { :id => '1'},
                :child => {
                  :tag => 'value',
                  :attributes => { :type => 'array' },
                  :children => { :count => 2 }
                }
              }
            }

          xml = Hash.from_xml(response.body)
          custom_fields = xml['issue']['custom_fields']
          assert_kind_of Array, custom_fields
          field = custom_fields.detect {|f| f['id'] == '1'}
          assert_kind_of Hash, field
          assert_equal ['MySQL', 'Oracle'], field['value'].sort
        end
      end

      context ".json" do
        should "display custom fields" do
          get '/issues/3.json'
          assert_response :success
          json = ActiveSupport::JSON.decode(response.body)
          custom_fields = json['issue']['custom_fields']
          assert_kind_of Array, custom_fields
          field = custom_fields.detect {|f| f['id'] == 1}
          assert_kind_of Hash, field
          assert_equal ['MySQL', 'Oracle'], field['value'].sort
        end
      end
    end

    context "with empty value for multi custom field" do
      setup do
        field = CustomField.find(1)
        field.update_attribute :multiple, true
        issue = Issue.find(3)
        issue.custom_field_values = {1 => ['']}
        issue.save!
      end

      context ".xml" do
        should "display custom fields" do
          get '/issues/3.xml'
          assert_response :success
          assert_tag :tag => 'issue',
            :child => {
              :tag => 'custom_fields',
              :attributes => { :type => 'array' },
              :child => {
                :tag => 'custom_field',
                :attributes => { :id => '1'},
                :child => {
                  :tag => 'value',
                  :attributes => { :type => 'array' },
                  :children => { :count => 0 }
                }
              }
            }

          xml = Hash.from_xml(response.body)
          custom_fields = xml['issue']['custom_fields']
          assert_kind_of Array, custom_fields
          field = custom_fields.detect {|f| f['id'] == '1'}
          assert_kind_of Hash, field
          assert_equal [], field['value']
        end
      end

      context ".json" do
        should "display custom fields" do
          get '/issues/3.json'
          assert_response :success
          json = ActiveSupport::JSON.decode(response.body)
          custom_fields = json['issue']['custom_fields']
          assert_kind_of Array, custom_fields
          field = custom_fields.detect {|f| f['id'] == 1}
          assert_kind_of Hash, field
          assert_equal [], field['value'].sort
        end
      end
    end

    context "with attachments" do
      context ".xml" do
        should "display attachments" do
          get '/issues/3.xml?include=attachments'

          assert_tag :tag => 'issue',
            :child => {
              :tag => 'attachments',
              :children => {:count => 5},
              :child => {
                :tag => 'attachment',
                :child => {
                  :tag => 'filename',
                  :content => 'source.rb',
                  :sibling => {
                    :tag => 'content_url',
                    :content => 'http://www.example.com/attachments/download/4/source.rb'
                  }
                }
              }
            }
        end
      end
    end

    context "with subtasks" do
      setup do
        @c1 = Issue.create!(
                :status_id => 1, :subject => "child c1",
                :tracker_id => 1, :project_id => 1, :author_id => 1,
                :parent_issue_id => 1
              )
        @c2 = Issue.create!(
                :status_id => 1, :subject => "child c2",
                :tracker_id => 1, :project_id => 1, :author_id => 1,
                :parent_issue_id => 1
              )
        @c3 = Issue.create!(
                :status_id => 1, :subject => "child c3",
                :tracker_id => 1, :project_id => 1, :author_id => 1,
                :parent_issue_id => @c1.id
              )
      end

      context ".xml" do
        should "display children" do
          get '/issues/1.xml?include=children'

          assert_tag :tag => 'issue',
            :child => {
              :tag => 'children',
              :children => {:count => 2},
              :child => {
                :tag => 'issue',
                :attributes => {:id => @c1.id.to_s},
                :child => {
                  :tag => 'subject',
                  :content => 'child c1',
                  :sibling => {
                    :tag => 'children',
                    :children => {:count => 1},
                    :child => {
                      :tag => 'issue',
                      :attributes => {:id => @c3.id.to_s}
                    }
                  }
                }
              }
            }
        end

        context ".json" do
          should "display children" do
            get '/issues/1.json?include=children'

            json = ActiveSupport::JSON.decode(response.body)
            assert_equal([
              {
                'id' => @c1.id, 'subject' => 'child c1', 'tracker' => {'id' => 1, 'name' => 'Bug'},
                'children' => [{'id' => @c3.id, 'subject' => 'child c3',
                                'tracker' => {'id' => 1, 'name' => 'Bug'} }]
              },
              { 'id' => @c2.id, 'subject' => 'child c2', 'tracker' => {'id' => 1, 'name' => 'Bug'} }
              ],
              json['issue']['children'])
          end
        end
      end
    end
  end

  test "GET /issues/:id.xml?include=watchers should include watchers" do
    Watcher.create!(:user_id => 3, :watchable => Issue.find(1))

    get '/issues/1.xml?include=watchers', {}, credentials('jsmith')

    assert_response :ok
    assert_equal 'application/xml', response.content_type
    assert_select 'issue' do
      assert_select 'watchers', Issue.find(1).watchers.count
      assert_select 'watchers' do
        assert_select 'user[id=3]'
      end
    end
  end

  context "POST /issues.xml" do
    should_allow_api_authentication(
      :post,
      '/issues.xml',
      {:issue => {:project_id => 1, :subject => 'API test', :tracker_id => 2, :status_id => 3}},
      {:success_code => :created}
    )
    should "create an issue with the attributes" do
      assert_difference('Issue.count') do
        post '/issues.xml',
             {:issue => {:project_id => 1, :subject => 'API test',
              :tracker_id => 2, :status_id => 3}}, credentials('jsmith')
      end
      issue = Issue.first(:order => 'id DESC')
      assert_equal 1, issue.project_id
      assert_equal 2, issue.tracker_id
      assert_equal 3, issue.status_id
      assert_equal 'API test', issue.subject

      assert_response :created
      assert_equal 'application/xml', @response.content_type
      assert_tag 'issue', :child => {:tag => 'id', :content => issue.id.to_s}
    end
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

  context "POST /issues.xml with failure" do
    should "have an errors tag" do
      assert_no_difference('Issue.count') do
        post '/issues.xml', {:issue => {:project_id => 1}}, credentials('jsmith')
      end

      assert_tag :errors, :child => {:tag => 'error', :content => "Subject can't be blank"}
    end
  end

  context "POST /issues.json" do
    should_allow_api_authentication(:post,
                                    '/issues.json',
                                    {:issue => {:project_id => 1, :subject => 'API test',
                                     :tracker_id => 2, :status_id => 3}},
                                    {:success_code => :created})

    should "create an issue with the attributes" do
      assert_difference('Issue.count') do
        post '/issues.json',
             {:issue => {:project_id => 1, :subject => 'API test',
                         :tracker_id => 2, :status_id => 3}},
             credentials('jsmith')
      end

      issue = Issue.first(:order => 'id DESC')
      assert_equal 1, issue.project_id
      assert_equal 2, issue.tracker_id
      assert_equal 3, issue.status_id
      assert_equal 'API test', issue.subject
    end

  end

  context "POST /issues.json with failure" do
    should "have an errors element" do
      assert_no_difference('Issue.count') do
        post '/issues.json', {:issue => {:project_id => 1}}, credentials('jsmith')
      end

      json = ActiveSupport::JSON.decode(response.body)
      assert json['errors'].include?("Subject can't be blank")
    end
  end

  # Issue 6 is on a private project
  context "PUT /issues/6.xml" do
    setup do
      @parameters = {:issue => {:subject => 'API update', :notes => 'A new note'}}
    end

    should_allow_api_authentication(:put,
                                    '/issues/6.xml',
                                    {:issue => {:subject => 'API update', :notes => 'A new note'}},
                                    {:success_code => :ok})

    should "not create a new issue" do
      assert_no_difference('Issue.count') do
        put '/issues/6.xml', @parameters, credentials('jsmith')
      end
    end

    should "create a new journal" do
      assert_difference('Journal.count') do
        put '/issues/6.xml', @parameters, credentials('jsmith')
      end
    end

    should "add the note to the journal" do
      put '/issues/6.xml', @parameters, credentials('jsmith')

      journal = Journal.last
      assert_equal "A new note", journal.notes
    end

    should "update the issue" do
      put '/issues/6.xml', @parameters, credentials('jsmith')

      issue = Issue.find(6)
      assert_equal "API update", issue.subject
    end

  end

  context "PUT /issues/3.xml with custom fields" do
    setup do
      @parameters = {
        :issue => {:custom_fields => [{'id' => '1', 'value' => 'PostgreSQL' },
        {'id' => '2', 'value' => '150'}]}
      }
    end

    should "update custom fields" do
      assert_no_difference('Issue.count') do
        put '/issues/3.xml', @parameters, credentials('jsmith')
      end

      issue = Issue.find(3)
      assert_equal '150', issue.custom_value_for(2).value
      assert_equal 'PostgreSQL', issue.custom_value_for(1).value
    end
  end

  context "PUT /issues/3.xml with multi custom fields" do
    setup do
      field = CustomField.find(1)
      field.update_attribute :multiple, true
      @parameters = {
        :issue => {:custom_fields => [{'id' => '1', 'value' => ['MySQL', 'PostgreSQL'] },
        {'id' => '2', 'value' => '150'}]}
      }
    end

    should "update custom fields" do
      assert_no_difference('Issue.count') do
        put '/issues/3.xml', @parameters, credentials('jsmith')
      end

      issue = Issue.find(3)
      assert_equal '150', issue.custom_value_for(2).value
      assert_equal ['MySQL', 'PostgreSQL'], issue.custom_field_value(1).sort
    end
  end

  context "PUT /issues/3.xml with project change" do
    setup do
      @parameters = {:issue => {:project_id => 2, :subject => 'Project changed'}}
    end

    should "update project" do
      assert_no_difference('Issue.count') do
        put '/issues/3.xml', @parameters, credentials('jsmith')
      end

      issue = Issue.find(3)
      assert_equal 2, issue.project_id
      assert_equal 'Project changed', issue.subject
    end
  end

  context "PUT /issues/6.xml with failed update" do
    setup do
      @parameters = {:issue => {:subject => ''}}
    end

    should "not create a new issue" do
      assert_no_difference('Issue.count') do
        put '/issues/6.xml', @parameters, credentials('jsmith')
      end
    end

    should "not create a new journal" do
      assert_no_difference('Journal.count') do
        put '/issues/6.xml', @parameters, credentials('jsmith')
      end
    end

    should "have an errors tag" do
      put '/issues/6.xml', @parameters, credentials('jsmith')

      assert_tag :errors, :child => {:tag => 'error', :content => "Subject can't be blank"}
    end
  end

  context "PUT /issues/6.json" do
    setup do
      @parameters = {:issue => {:subject => 'API update', :notes => 'A new note'}}
    end

    should_allow_api_authentication(:put,
                                    '/issues/6.json',
                                    {:issue => {:subject => 'API update', :notes => 'A new note'}},
                                    {:success_code => :ok})

    should "update the issue" do
      assert_no_difference('Issue.count') do
        assert_difference('Journal.count') do
          put '/issues/6.json', @parameters, credentials('jsmith')

          assert_response :ok
          assert_equal '', response.body
        end
      end

      issue = Issue.find(6)
      assert_equal "API update", issue.subject
      journal = Journal.last
      assert_equal "A new note", journal.notes
    end
  end

  context "PUT /issues/6.json with failed update" do
    should "return errors" do
      assert_no_difference('Issue.count') do
        assert_no_difference('Journal.count') do
          put '/issues/6.json', {:issue => {:subject => ''}}, credentials('jsmith')

          assert_response :unprocessable_entity
        end
      end

      json = ActiveSupport::JSON.decode(response.body)
      assert json['errors'].include?("Subject can't be blank")
    end
  end

  context "DELETE /issues/1.xml" do
    should_allow_api_authentication(:delete,
                                    '/issues/6.xml',
                                    {},
                                    {:success_code => :ok})

    should "delete the issue" do
      assert_difference('Issue.count', -1) do
        delete '/issues/6.xml', {}, credentials('jsmith')

        assert_response :ok
        assert_equal '', response.body
      end

      assert_nil Issue.find_by_id(6)
    end
  end

  context "DELETE /issues/1.json" do
    should_allow_api_authentication(:delete,
                                    '/issues/6.json',
                                    {},
                                    {:success_code => :ok})

    should "delete the issue" do
      assert_difference('Issue.count', -1) do
        delete '/issues/6.json', {}, credentials('jsmith')

        assert_response :ok
        assert_equal '', response.body
      end

      assert_nil Issue.find_by_id(6)
    end
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
    set_tmp_attachments_directory
    # upload the file
    assert_difference 'Attachment.count' do
      post '/uploads.xml', 'test_create_with_upload',
           {"CONTENT_TYPE" => 'application/octet-stream'}.merge(credentials('jsmith'))
      assert_response :created
    end
    xml = Hash.from_xml(response.body)
    token = xml['upload']['token']
    attachment = Attachment.first(:order => 'id DESC')

    # create the issue with the upload's token
    assert_difference 'Issue.count' do
      post '/issues.xml',
           {:issue => {:project_id => 1, :subject => 'Uploaded file',
                       :uploads => [{:token => token, :filename => 'test.txt',
                                     :content_type => 'text/plain'}]}},
           credentials('jsmith')
      assert_response :created
    end
    issue = Issue.first(:order => 'id DESC')
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
  end

  def test_update_issue_with_uploaded_file
    set_tmp_attachments_directory
    # upload the file
    assert_difference 'Attachment.count' do
      post '/uploads.xml', 'test_upload_with_upload',
           {"CONTENT_TYPE" => 'application/octet-stream'}.merge(credentials('jsmith'))
      assert_response :created
    end
    xml = Hash.from_xml(response.body)
    token = xml['upload']['token']
    attachment = Attachment.first(:order => 'id DESC')

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
