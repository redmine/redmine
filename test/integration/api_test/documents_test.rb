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

require_relative '../../test_helper'

class Redmine::ApiTest::DocumentsTest < Redmine::ApiTest::Base
  test "GET /projects/:project_id/documents.xml should return documents" do
    get '/projects/ecookbook/documents.xml'

    assert_response :success
    assert_equal 'application/xml', response.media_type
    assert_select 'documents[type=array][total_count=?]', Project.find(1).documents.count.to_s do
      assert_select 'document', 3
      # documents are sorted by descending creation date
      assert_select 'document:first-of-type' do
        assert_select 'id', :text => '3'
        assert_select 'project[id=1][name=eCookbook]'
        assert_select 'category[id=3][name="Technical documentation"]'
        assert_select 'title', :text => 'An other document 2'
        assert_select 'created_on', :text => Document.find(3).created_on.iso8601
        assert_select 'updated_on', :text => Document.find(3).updated_on.iso8601
      end
    end
  end

  test "GET /projects/:project_id/documents.json should return documents" do
    get '/projects/ecookbook/documents.json'

    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json
    assert_kind_of Array, json['documents']
    assert_equal Project.find(1).documents.count, json['total_count']
    # documents are sorted by descending creation date
    assert_equal 3, json['documents'].first['id']
    assert_equal({'id' => 3, 'name' => 'Technical documentation'}, json['documents'].first['category'])
  end

  test "GET /projects/:project_id/documents.xml should paginate" do
    get '/projects/ecookbook/documents.xml', :params => {:limit => 2, :offset => 1}

    assert_response :success
    assert_select 'documents[type=array][total_count="3"][offset="1"][limit="2"]' do
      assert_select 'document', 2
      assert_select 'document id', :text => '2'
      assert_select 'document id', :text => '1'
    end
  end

  test "GET /projects/:project_id/documents.xml without permission should return 401 for anonymous user" do
    Role.anonymous.remove_permission! :view_documents

    get '/projects/ecookbook/documents.xml'
    assert_response :unauthorized
  end

  test "GET /projects/:project_id/documents.xml without permission should return 403" do
    Role.find(1).remove_permission! :view_documents

    get '/projects/ecookbook/documents.xml', :headers => credentials('jsmith')

    assert_response :forbidden
  end

  test "GET /documents/:id.xml should return the document" do
    get '/documents/1.xml'

    assert_response :success
    assert_equal 'application/xml', response.media_type
    assert_select 'document' do
      assert_select 'id', :text => '1'
      assert_select 'project[id=1][name=eCookbook]'
      assert_select 'category[id=1][name=Uncategorized]'
      assert_select 'title', :text => 'Test document'
      assert_select 'description', :text => 'Document description'
      assert_select 'created_on', :text => Document.find(1).created_on.iso8601
      assert_select 'updated_on', :text => Document.find(1).updated_on.iso8601
      assert_select 'attachments', 0
    end
  end

  test "GET /documents/:id.json should return the document" do
    get '/documents/1.json'

    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json['document']
    assert_equal 1, json['document']['id']
    assert_equal 'Test document', json['document']['title']
  end

  test "GET /documents/:id.xml with include=attachments should include attachments" do
    get '/documents/1.xml?include=attachments'

    assert_select 'document attachments[type=array]' do
      assert_select 'attachment', 2
      assert_select 'attachment id', :text => '2' do
        assert_select '~ filename', :text => 'document.txt'
        assert_select '~ content_url',
                      :text => 'http://www.example.com/attachments/download/2/document.txt'
      end
    end
  end

  test "GET /documents/:id.xml should include custom fields" do
    field = DocumentCustomField.generate!(:name => 'Author', :field_format => 'string')
    document = Document.find(1)
    document.custom_field_values = {field.id => 'John Smith'}
    document.save!

    get '/documents/1.xml'

    assert_response :success
    assert_select 'document custom_fields[type=array]' do
      assert_select "custom_field[id=\"#{field.id}\"][name=Author]" do
        assert_select 'value', :text => 'John Smith'
      end
    end
  end

  test "GET /documents/:id.xml on a private project without credentials should return 401" do
    Document.find(1).project.update_column :is_public, false

    get '/documents/1.xml'

    assert_response :unauthorized
  end

  test "POST /projects/:project_id/documents.xml should create a document with the attributes" do
    payload = <<~XML
      <?xml version="1.0" encoding="UTF-8" ?>
      <document>
        <title>API document</title>
        <description>This is a document created by the API</description>
        <category_id>2</category_id>
      </document>
    XML
    assert_difference('Document.count') do
      post(
        '/projects/1/documents.xml',
        :params => payload,
        :headers => {"CONTENT_TYPE" => 'application/xml'}.merge(credentials('jsmith')))
    end
    assert_response :created
    assert_equal 'application/xml', response.media_type

    document = Document.order(:id => :desc).first
    assert_equal 'API document', document.title
    assert_equal 'This is a document created by the API', document.description
    assert_equal DocumentCategory.find(2), document.category
    assert_equal Project.find(1), document.project
    assert_equal document_url(document), response.headers['Location']
    assert_select 'document id', :text => document.id.to_s
  end

  test "POST /projects/:project_id/documents.json should create a document with the attributes" do
    payload = <<~JSON
      {
        "document": {
          "title": "API document",
          "description": "This is a document created by the API",
          "category_id": 2
        }
      }
    JSON
    assert_difference('Document.count') do
      post(
        '/projects/1/documents.json',
        :params => payload,
        :headers => {"CONTENT_TYPE" => 'application/json'}.merge(credentials('jsmith')))
    end
    assert_response :created

    document = Document.order(:id => :desc).first
    assert_equal 'API document', document.title
    assert_equal 'This is a document created by the API', document.description

    json = ActiveSupport::JSON.decode(response.body)
    assert_equal document.id, json['document']['id']
  end

  test "POST /projects/:project_id/documents.json with failure should return errors" do
    assert_no_difference('Document.count') do
      post(
        '/projects/1/documents.json',
        :params => {:document => {:title => '', :category_id => 1}},
        :headers => credentials('jsmith'))
    end
    assert_response :unprocessable_content
    json = ActiveSupport::JSON.decode(response.body)
    assert json['errors'].include?("Title cannot be blank")
  end

  test "POST /projects/:project_id/documents.json with attachment should create a document with attachment" do
    token = json_upload('test_create_with_attachment', credentials('jsmith'))
    attachment = Attachment.find_by_token(token)
    assert_difference 'Document.count' do
      post(
        '/projects/1/documents.json',
        :params => {:document => {:title => 'API document with attachment',
                                  :category_id => 1,
                                  :uploads => [{:token => token, :filename => 'test.txt',
                                                :content_type => 'text/plain'}]}},
        :headers => credentials('jsmith'))
      assert_response :created
    end
    document = Document.order(:id => :desc).first
    assert_equal 'API document with attachment', document.title
    assert_equal attachment, document.attachments.first

    attachment.reload
    assert_equal 'test.txt', attachment.filename
    assert_equal 'text/plain', attachment.content_type
    assert_equal 'test_create_with_attachment'.size, attachment.filesize
    assert_equal 2, attachment.author_id
  end

  test "POST /projects/:project_id/documents.xml with attachment should create a document with attachment" do
    token = xml_upload('test_create_with_attachment', credentials('jsmith'))
    payload = <<~XML
      <?xml version="1.0" encoding="UTF-8" ?>
      <document>
        <title>API document with attachment</title>
        <category_id>1</category_id>
        <uploads type="array">
          <upload>
            <token>#{token}</token>
            <filename>test.txt</filename>
          </upload>
        </uploads>
      </document>
    XML
    assert_difference 'Document.count' do
      post(
        '/projects/1/documents.xml',
        :params => payload,
        :headers => {"CONTENT_TYPE" => 'application/xml'}.merge(credentials('jsmith')))
      assert_response :created
    end
    document = Document.order(:id => :desc).first
    assert_equal ['test.txt'], document.attachments.map(&:filename)
  end

  test "POST /projects/:project_id/documents.xml without permission should return 403" do
    Role.find(1).remove_permission! :add_documents

    assert_no_difference 'Document.count' do
      post(
        '/projects/1/documents.xml',
        :params => {:document => {:title => 'API document'}},
        :headers => credentials('jsmith'))
    end
    assert_response :forbidden
  end

  test "PUT /documents/:id.xml should update the document" do
    payload = <<~XML
      <?xml version="1.0" encoding="UTF-8" ?>
      <document>
        <title>Updated title</title>
        <description>Updated description</description>
        <category_id>2</category_id>
      </document>
    XML
    put(
      '/documents/1.xml',
      :params => payload,
      :headers => {"CONTENT_TYPE" => 'application/xml'}.merge(credentials('jsmith')))

    assert_response :no_content
    assert_equal '', response.body
    document = Document.find(1)
    assert_equal 'Updated title', document.title
    assert_equal 'Updated description', document.description
    assert_equal DocumentCategory.find(2), document.category
  end

  test "PUT /documents/:id.xml with failure should return errors" do
    put(
      '/documents/1.xml',
      :params => {:document => {:title => ''}},
      :headers => credentials('jsmith'))

    assert_response :unprocessable_content
    assert_select 'errors error', :text => "Title cannot be blank"
  end

  test "PUT /documents/:id.json should update the document" do
    put(
      '/documents/1.json',
      :params => {:document => {:title => 'Updated title'}},
      :headers => credentials('jsmith'))

    assert_response :no_content
    assert_equal 'Updated title', Document.find(1).title
  end

  test "PUT /documents/:id.json with failure should return errors" do
    put(
      '/documents/1.json',
      :params => {:document => {:title => ''}},
      :headers => credentials('jsmith'))

    assert_response :unprocessable_content
    json = ActiveSupport::JSON.decode(response.body)
    assert json['errors'].include?("Title cannot be blank")
  end

  test "PUT /documents/:id.json with attachment should add the attachment" do
    token = json_upload('test_update_with_attachment', credentials('jsmith'))

    put(
      '/documents/2.json',
      :params => {:document => {:uploads => [{:token => token, :filename => 'test.txt',
                                              :content_type => 'text/plain'}]}},
      :headers => credentials('jsmith'))

    assert_response :no_content
    assert_equal ['test.txt'], Document.find(2).attachments.map(&:filename)
  end

  test "PUT /documents/:id.xml with attachment should add the attachment" do
    token = xml_upload('test_update_with_attachment', credentials('jsmith'))
    payload = <<~XML
      <?xml version="1.0" encoding="UTF-8" ?>
      <document>
        <uploads type="array">
          <upload>
            <token>#{token}</token>
            <filename>test.txt</filename>
          </upload>
        </uploads>
      </document>
    XML
    put(
      '/documents/2.xml',
      :params => payload,
      :headers => {"CONTENT_TYPE" => 'application/xml'}.merge(credentials('jsmith')))

    assert_response :no_content
    assert_equal ['test.txt'], Document.find(2).attachments.map(&:filename)
  end

  test "PUT /documents/:id.xml without permission should return 403" do
    Role.find(1).remove_permission! :edit_documents

    put(
      '/documents/1.xml',
      :params => {:document => {:title => 'Updated title'}},
      :headers => credentials('jsmith'))

    assert_response :forbidden
  end

  test "DELETE /documents/:id.xml should delete the document" do
    assert_difference('Document.count', -1) do
      delete '/documents/1.xml', :headers => credentials('jsmith')
    end

    assert_response :no_content
    assert_equal '', response.body
    assert_nil Document.find_by_id(1)
  end

  test "DELETE /documents/:id.json should delete the document" do
    assert_difference('Document.count', -1) do
      delete '/documents/1.json', :headers => credentials('jsmith')
    end

    assert_response :no_content
    assert_nil Document.find_by_id(1)
  end

  test "DELETE /documents/:id.xml without permission should return 403" do
    Role.find(1).remove_permission! :delete_documents

    assert_no_difference 'Document.count' do
      delete '/documents/1.xml', :headers => credentials('jsmith')
    end

    assert_response :forbidden
  end
end
