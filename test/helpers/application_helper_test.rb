# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

require File.expand_path('../../test_helper', __FILE__)

class ApplicationHelperTest < Redmine::HelperTest
  include ERB::Util
  include Rails.application.routes.url_helpers

  fixtures :projects, :enabled_modules,
           :users, :email_addresses,
           :members, :member_roles, :roles,
           :repositories, :changesets,
           :projects_trackers,
           :trackers, :issue_statuses, :issues, :versions, :documents, :journals,
           :wikis, :wiki_pages, :wiki_contents,
           :boards, :messages, :news,
           :attachments, :enumerations,
           :custom_values, :custom_fields, :custom_fields_projects

  def setup
    super
    set_tmp_attachments_directory
    @russian_test = 'тест'
  end

  test "#link_to_if_authorized for authorized user should allow using the :controller and :action for the target link" do
    User.current = User.find_by_login('admin')

    @project = Issue.first.project # Used by helper
    response = link_to_if_authorized(
                 'By controller/actionr',
                 {:controller => 'issues', :action => 'edit', :id => Issue.first.id})
    assert_match /href/, response
  end

  test "#link_to_if_authorized for unauthorized user should display nothing if user isn't authorized" do
    User.current = User.find_by_login('dlopper')
    @project = Project.find('private-child')
    issue = @project.issues.first
    assert !issue.visible?
    response = link_to_if_authorized(
                 'Never displayed',
                 {:controller => 'issues', :action => 'show', :id => issue})
    assert_nil response
  end

  def test_auto_links
    to_test = {
      'http://foo.bar' => '<a class="external" href="http://foo.bar">http://foo.bar</a>',
      'http://foo.bar/~user' => '<a class="external" href="http://foo.bar/~user">http://foo.bar/~user</a>',
      'http://foo.bar.' => '<a class="external" href="http://foo.bar">http://foo.bar</a>.',
      'https://foo.bar.' => '<a class="external" href="https://foo.bar">https://foo.bar</a>.',
      'This is a link: http://foo.bar.' => 'This is a link: <a class="external" href="http://foo.bar">http://foo.bar</a>.',
      'A link (eg. http://foo.bar).' => 'A link (eg. <a class="external" href="http://foo.bar">http://foo.bar</a>).',
      'http://foo.bar/foo.bar#foo.bar.' => '<a class="external" href="http://foo.bar/foo.bar#foo.bar">http://foo.bar/foo.bar#foo.bar</a>.',
      'http://www.foo.bar/Test_(foobar)' => '<a class="external" href="http://www.foo.bar/Test_(foobar)">http://www.foo.bar/Test_(foobar)</a>',
      '(see inline link : http://www.foo.bar/Test_(foobar))' => '(see inline link : <a class="external" href="http://www.foo.bar/Test_(foobar)">http://www.foo.bar/Test_(foobar)</a>)',
      '(see inline link : http://www.foo.bar/Test)' => '(see inline link : <a class="external" href="http://www.foo.bar/Test">http://www.foo.bar/Test</a>)',
      '(see inline link : http://www.foo.bar/Test).' => '(see inline link : <a class="external" href="http://www.foo.bar/Test">http://www.foo.bar/Test</a>).',
      '(see "inline link":http://www.foo.bar/Test_(foobar))' => '(see <a href="http://www.foo.bar/Test_(foobar)" class="external">inline link</a>)',
      '(see "inline link":http://www.foo.bar/Test)' => '(see <a href="http://www.foo.bar/Test" class="external">inline link</a>)',
      '(see "inline link":http://www.foo.bar/Test).' => '(see <a href="http://www.foo.bar/Test" class="external">inline link</a>).',
      'www.foo.bar' => '<a class="external" href="http://www.foo.bar">www.foo.bar</a>',
      'http://foo.bar/page?p=1&t=z&s=' => '<a class="external" href="http://foo.bar/page?p=1&#38;t=z&#38;s=">http://foo.bar/page?p=1&#38;t=z&#38;s=</a>',
      'http://foo.bar/page#125' => '<a class="external" href="http://foo.bar/page#125">http://foo.bar/page#125</a>',
      'http://foo@www.bar.com' => '<a class="external" href="http://foo@www.bar.com">http://foo@www.bar.com</a>',
      'http://foo:bar@www.bar.com' => '<a class="external" href="http://foo:bar@www.bar.com">http://foo:bar@www.bar.com</a>',
      'ftp://foo.bar' => '<a class="external" href="ftp://foo.bar">ftp://foo.bar</a>',
      'ftps://foo.bar' => '<a class="external" href="ftps://foo.bar">ftps://foo.bar</a>',
      'sftp://foo.bar' => '<a class="external" href="sftp://foo.bar">sftp://foo.bar</a>',
      # two exclamation marks
      'http://example.net/path!602815048C7B5C20!302.html' => '<a class="external" href="http://example.net/path!602815048C7B5C20!302.html">http://example.net/path!602815048C7B5C20!302.html</a>',
      # escaping
      'http://foo"bar' => '<a class="external" href="http://foo&quot;bar">http://foo&quot;bar</a>',
      # wrap in angle brackets
      '<http://foo.bar>' => '&lt;<a class="external" href="http://foo.bar">http://foo.bar</a>&gt;',
      # invalid urls
      'http://' => 'http://',
      'www.' => 'www.',
      'test-www.bar.com' => 'test-www.bar.com',
      # ends with a hyphen
      'http://www.redmine.org/example-' => '<a class="external" href="http://www.redmine.org/example-">http://www.redmine.org/example-</a>',
    }
    to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text) }
  end

  def test_auto_links_with_non_ascii_characters
    to_test = {
      "http://foo.bar/#{@russian_test}" =>
        %|<a class="external" href="http://foo.bar/#{@russian_test}">http://foo.bar/#{@russian_test}</a>|
    }
    to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text) }
  end

  def test_auto_mailto
    to_test = {
      'test@foo.bar' => '<a class="email" href="mailto:test@foo.bar">test@foo.bar</a>',
      'test@www.foo.bar' => '<a class="email" href="mailto:test@www.foo.bar">test@www.foo.bar</a>',
    }
    to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text) }
  end

  def test_inline_images
    to_test = {
      '!http://foo.bar/image.jpg!' => '<img src="http://foo.bar/image.jpg" alt="" />',
      'floating !>http://foo.bar/image.jpg!' => 'floating <span style="float:right"><img src="http://foo.bar/image.jpg" alt="" /></span>',
      'with class !(some-class)http://foo.bar/image.jpg!' => 'with class <img src="http://foo.bar/image.jpg" class="wiki-class-some-class" alt="" />',
      'with class !(wiki-class-foo)http://foo.bar/image.jpg!' => 'with class <img src="http://foo.bar/image.jpg" class="wiki-class-foo" alt="" />',
      'with style !{width:100px;height:100px}http://foo.bar/image.jpg!' => 'with style <img src="http://foo.bar/image.jpg" style="width:100px;height:100px;" alt="" />',
      'with title !http://foo.bar/image.jpg(This is a title)!' => 'with title <img src="http://foo.bar/image.jpg" title="This is a title" alt="This is a title" />',
      'with title !http://foo.bar/image.jpg(This is a double-quoted "title")!' => 'with title <img src="http://foo.bar/image.jpg" title="This is a double-quoted &quot;title&quot;" alt="This is a double-quoted &quot;title&quot;" />',
    }
    to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text) }
  end

  def test_inline_images_inside_tags
    raw = <<~RAW
      h1. !foo.png! Heading

      Centered image:

      p=. !bar.gif!
    RAW
    assert textilizable(raw).include?('<img src="foo.png" alt="" />')
    assert textilizable(raw).include?('<img src="bar.gif" alt="" />')
  end

  def test_attached_images
    to_test = {
      'Inline image: !logo.gif!' => 'Inline image: <img src="/attachments/download/3/logo.gif" title="This is a logo" alt="This is a logo" />',
      'Inline image: !logo.GIF!' => 'Inline image: <img src="/attachments/download/3/logo.gif" title="This is a logo" alt="This is a logo" />',
      'No match: !ogo.gif!' => 'No match: <img src="ogo.gif" alt="" />',
      'No match: !ogo.GIF!' => 'No match: <img src="ogo.GIF" alt="" />',
      # link image
      '!logo.gif!:http://foo.bar/' => '<a href="http://foo.bar/"><img src="/attachments/download/3/logo.gif" title="This is a logo" alt="This is a logo" /></a>',
    }
    attachments = Attachment.all
    to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text, :attachments => attachments) }
  end

  def test_attached_images_with_textile_and_non_ascii_filename
    to_test = {
      'CAFÉ.JPG' => 'CAF%C3%89.JPG',
      'crème.jpg' => 'cr%C3%A8me.jpg',
    }
    with_settings :text_formatting => 'textile' do
      to_test.each do |filename, result|
        attachment = Attachment.generate!(:filename => filename)
        assert_include %(<img src="/attachments/download/#{attachment.id}/#{result}" alt="" />), textilizable("!#{filename}!", :attachments => [attachment])
      end
    end
  end

  def test_attached_images_with_markdown_and_non_ascii_filename
    skip unless Object.const_defined?(:Redcarpet)

    to_test = {
      'CAFÉ.JPG' => 'CAF%C3%89.JPG',
      'crème.jpg' => 'cr%C3%A8me.jpg',
    }
    with_settings :text_formatting => 'markdown' do
      to_test.each do |filename, result|
        attachment = Attachment.generate!(:filename => filename)
        assert_include %(<img src="/attachments/download/#{attachment.id}/#{result}" alt="" />), textilizable("![](#{filename})", :attachments => [attachment])
      end
    end
  end

  def test_attached_images_with_hires_naming
    attachment = Attachment.generate!(:filename => 'image@2x.png')
    assert_equal(
        %(<p><img src="/attachments/download/#{attachment.id}/image@2x.png" srcset="/attachments/download/#{attachment.id}/image@2x.png 2x" alt="" /></p>),
        textilizable("!image@2x.png!", :attachments => [attachment]))
  end

  def test_attached_images_filename_extension
    a1 = Attachment.new(
            :container => Issue.find(1),
            :file => mock_file_with_options({:original_filename => "testtest.JPG"}),
            :author => User.find(1))
    assert a1.save
    assert_equal "testtest.JPG", a1.filename
    assert_equal "image/jpeg", a1.content_type
    assert a1.image?

    a2 = Attachment.new(
            :container => Issue.find(1),
            :file => mock_file_with_options({:original_filename => "testtest.jpeg"}),
            :author => User.find(1))
    assert a2.save
    assert_equal "testtest.jpeg", a2.filename
    assert_equal "image/jpeg", a2.content_type
    assert a2.image?

    a3 = Attachment.new(
            :container => Issue.find(1),
            :file => mock_file_with_options({:original_filename => "testtest.JPE"}),
            :author => User.find(1))
    assert a3.save
    assert_equal "testtest.JPE", a3.filename
    assert_equal "image/jpeg", a3.content_type
    assert a3.image?

    a4 = Attachment.new(
            :container => Issue.find(1),
            :file => mock_file_with_options({:original_filename => "Testtest.BMP"}),
            :author => User.find(1))
    assert a4.save
    assert_equal "Testtest.BMP", a4.filename
    assert_equal "image/x-ms-bmp", a4.content_type
    assert a4.image?

    to_test = {
      'Inline image: !testtest.jpg!' =>
        'Inline image: <img src="/attachments/download/' + a1.id.to_s + '/testtest.JPG" alt="" />',
      'Inline image: !testtest.jpeg!' =>
        'Inline image: <img src="/attachments/download/' + a2.id.to_s + '/testtest.jpeg" alt="" />',
      'Inline image: !testtest.jpe!' =>
        'Inline image: <img src="/attachments/download/' + a3.id.to_s + '/testtest.JPE" alt="" />',
      'Inline image: !testtest.bmp!' =>
        'Inline image: <img src="/attachments/download/' + a4.id.to_s + '/Testtest.BMP" alt="" />',
    }

    attachments = [a1, a2, a3, a4]
    to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text, :attachments => attachments) }
  end

  def test_attached_images_should_read_later
    set_fixtures_attachments_directory
    a1 = Attachment.find(16)
    assert_equal "testfile.png", a1.filename
    assert a1.readable?
    assert (! a1.visible?(User.anonymous))
    assert a1.visible?(User.find(2))
    a2 = Attachment.find(17)
    assert_equal "testfile.PNG", a2.filename
    assert a2.readable?
    assert (! a2.visible?(User.anonymous))
    assert a2.visible?(User.find(2))
    assert a1.created_on < a2.created_on

    to_test = {
      'Inline image: !testfile.png!' =>
        'Inline image: <img src="/attachments/download/' + a2.id.to_s + '/testfile.PNG" alt="" />',
      'Inline image: !Testfile.PNG!' =>
        'Inline image: <img src="/attachments/download/' + a2.id.to_s + '/testfile.PNG" alt="" />',
    }
    attachments = [a1, a2]
    to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text, :attachments => attachments) }
  ensure
    set_tmp_attachments_directory
  end

  def test_textile_external_links
    to_test = {
      'This is a "link":http://foo.bar' => 'This is a <a href="http://foo.bar" class="external">link</a>',
      'This is an intern "link":/foo/bar' => 'This is an intern <a href="/foo/bar">link</a>',
      '"link (Link title)":http://foo.bar' => '<a href="http://foo.bar" title="Link title" class="external">link</a>',
      '"link (Link title with "double-quotes")":http://foo.bar' => '<a href="http://foo.bar" title="Link title with &quot;double-quotes&quot;" class="external">link</a>',
      "This is not a \"Link\":\n\nAnother paragraph" => "This is not a \"Link\":</p>\n\n\n\t<p>Another paragraph",
      # no multiline link text
      "This is a double quote \"on the first line\nand another on a second line\":test" => "This is a double quote \"on the first line<br />and another on a second line\":test",
      # mailto link
      "\"system administrator\":mailto:sysadmin@example.com?subject=redmine%20permissions" => "<a href=\"mailto:sysadmin@example.com?subject=redmine%20permissions\">system administrator</a>",
      # two exclamation marks
      '"a link":http://example.net/path!602815048C7B5C20!302.html' => '<a href="http://example.net/path!602815048C7B5C20!302.html" class="external">a link</a>',
      # escaping
      '"test":http://foo"bar' => '<a href="http://foo&quot;bar" class="external">test</a>',
      # ends with a hyphen
      '(see "inline link":http://www.foo.bar/Test-)' => '(see <a href="http://www.foo.bar/Test-" class="external">inline link</a>)',
      'http://foo.bar/page?p=1&t=z&s=-' => '<a class="external" href="http://foo.bar/page?p=1&#38;t=z&#38;s=-">http://foo.bar/page?p=1&#38;t=z&#38;s=-</a>',
      'This is an intern "link":/foo/bar-' => 'This is an intern <a href="/foo/bar-">link</a>',    }
    to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text) }
  end

  def test_textile_external_links_with_non_ascii_characters
    to_test = {
      %|This is a "link":http://foo.bar/#{@russian_test}| =>
        %|This is a <a href="http://foo.bar/#{@russian_test}" class="external">link</a>|
    }
    to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text) }
  end

  def test_redmine_links
    user_with_email_login = User.generate!(:login => 'abcd@example.com')
    user_with_email_login_2 = User.generate!(:login => 'foo.bar@example.com')
    u_email_id = user_with_email_login.id
    u_email_id_2 = user_with_email_login_2.id

    issue_link = link_to('#3',
                         {:controller => 'issues', :action => 'show', :id => 3},
                         :class => Issue.find(3).css_classes,
                         :title => 'Bug: Error 281 when updating a recipe (New)')
    ext_issue_link = link_to(
                         'Bug #3: Error 281 when updating a recipe',
                         {:controller => 'issues', :action => 'show', :id => 3},
                         :class => Issue.find(3).css_classes,
                         :title => 'Status: New')
    note_link = link_to(
                         '#3-14',
                         {:controller => 'issues', :action => 'show',
                          :id => 3, :anchor => 'note-14'},
                         :class => Issue.find(3).css_classes,
                         :title => 'Bug: Error 281 when updating a recipe (New)')
    ext_note_link = link_to(
                         'Bug #3-14: Error 281 when updating a recipe',
                         {:controller => 'issues', :action => 'show',
                          :id => 3, :anchor => 'note-14'},
                         :class => Issue.find(3).css_classes,
                         :title => 'Status: New')
    note_link2 = link_to(
                         '#3#note-14',
                         {:controller => 'issues', :action => 'show',
                          :id => 3, :anchor => 'note-14'},
                         :class => Issue.find(3).css_classes,
                         :title => 'Bug: Error 281 when updating a recipe (New)')
    ext_note_link2 = link_to(
                         'Bug #3#note-14: Error 281 when updating a recipe',
                         {:controller => 'issues', :action => 'show',
                          :id => 3, :anchor => 'note-14'},
                         :class => Issue.find(3).css_classes,
                         :title => 'Status: New')

    revision_link = link_to(
                         'r1',
                         {:controller => 'repositories', :action => 'revision',
                          :id => 'ecookbook', :repository_id => 10, :rev => 1},
                         :class => 'changeset',
                         :title => 'My very first commit do not escaping #<>&')
    revision_link2 = link_to(
                         'r2',
                         {:controller => 'repositories', :action => 'revision',
                          :id => 'ecookbook', :repository_id => 10, :rev => 2},
                         :class => 'changeset',
                         :title => 'This commit fixes #1, #2 and references #1 & #3')

    changeset_link2 = link_to(
                         '691322a8eb01e11fd7',
                         {:controller => 'repositories', :action => 'revision',
                          :id => 'ecookbook', :repository_id => 10, :rev => 1},
                         :class => 'changeset', :title => 'My very first commit do not escaping #<>&')

    document_link = link_to(
                         'Test document',
                         {:controller => 'documents', :action => 'show', :id => 1},
                         :class => 'document')

    version_link = link_to('1.0',
                           {:controller => 'versions', :action => 'show', :id => 2},
                           :class => 'version')

    board_url = {:controller => 'boards', :action => 'show', :id => 2, :project_id => 'ecookbook'}

    message_url = {:controller => 'messages', :action => 'show', :board_id => 1, :id => 4}

    news_url = {:controller => 'news', :action => 'show', :id => 1}

    project_url = {:controller => 'projects', :action => 'show', :id => 'subproject1'}

    source_url = '/projects/ecookbook/repository/10/entry/some/file'
    source_url_with_rev = '/projects/ecookbook/repository/10/revisions/52/entry/some/file'
    source_url_with_ext = '/projects/ecookbook/repository/10/entry/some/file.ext'
    source_url_with_rev_and_ext = '/projects/ecookbook/repository/10/revisions/52/entry/some/file.ext'
    source_url_with_branch = '/projects/ecookbook/repository/10/revisions/branch/entry/some/file'

    export_url = '/projects/ecookbook/repository/10/raw/some/file'
    export_url_with_rev = '/projects/ecookbook/repository/10/revisions/52/raw/some/file'
    export_url_with_ext = '/projects/ecookbook/repository/10/raw/some/file.ext'
    export_url_with_rev_and_ext = '/projects/ecookbook/repository/10/revisions/52/raw/some/file.ext'
    export_url_with_branch = '/projects/ecookbook/repository/10/revisions/branch/raw/some/file'

    to_test = {
      # tickets
      '#3, [#3], (#3) and #3.'      => "#{issue_link}, [#{issue_link}], (#{issue_link}) and #{issue_link}.",
      # ticket notes
      '#3-14'                       => note_link,
      '#3#note-14'                  => note_link2,
      # should not ignore leading zero
      '#03'                         => '#03',
      # tickets with more info
      '##3, [##3], (##3) and ##3.'  => "#{ext_issue_link}, [#{ext_issue_link}], (#{ext_issue_link}) and #{ext_issue_link}.",
      '##3-14'                      => ext_note_link,
      '##3#note-14'                 => ext_note_link2,
      '##03'                        => '##03',
      # changesets
      'r1'                          => revision_link,
      'r1.'                         => "#{revision_link}.",
      'r1, r2'                      => "#{revision_link}, #{revision_link2}",
      'r1,r2'                       => "#{revision_link},#{revision_link2}",
      'commit:691322a8eb01e11fd7'   => changeset_link2,
      # documents
      'document#1'                  => document_link,
      'document:"Test document"'    => document_link,
      # versions
      'version#2'                   => version_link,
      'version:1.0'                 => version_link,
      'version:"1.0"'               => version_link,
      # source
      'source:some/file'            => link_to('source:some/file', source_url, :class => 'source'),
      'source:/some/file'           => link_to('source:/some/file', source_url, :class => 'source'),
      'source:/some/file.'          => link_to('source:/some/file', source_url, :class => 'source') + ".",
      'source:/some/file.ext.'      => link_to('source:/some/file.ext', source_url_with_ext, :class => 'source') + ".",
      'source:/some/file. '         => link_to('source:/some/file', source_url, :class => 'source') + ".",
      'source:/some/file.ext. '     => link_to('source:/some/file.ext', source_url_with_ext, :class => 'source') + ".",
      'source:/some/file, '         => link_to('source:/some/file', source_url, :class => 'source') + ",",
      'source:/some/file@52'        => link_to('source:/some/file@52', source_url_with_rev, :class => 'source'),
      'source:/some/file@branch'    => link_to('source:/some/file@branch', source_url_with_branch, :class => 'source'),
      'source:/some/file.ext@52'    => link_to('source:/some/file.ext@52', source_url_with_rev_and_ext, :class => 'source'),
      'source:/some/file#L110'      => link_to('source:/some/file#L110', source_url + "#L110", :class => 'source'),
      'source:/some/file.ext#L110'  => link_to('source:/some/file.ext#L110', source_url_with_ext + "#L110", :class => 'source'),
      'source:/some/file@52#L110'   => link_to('source:/some/file@52#L110', source_url_with_rev + "#L110", :class => 'source'),
      # export
      'export:/some/file'           => link_to('export:/some/file', export_url, :class => 'source download'),
      'export:/some/file.ext'       => link_to('export:/some/file.ext', export_url_with_ext, :class => 'source download'),
      'export:/some/file@52'        => link_to('export:/some/file@52', export_url_with_rev, :class => 'source download'),
      'export:/some/file.ext@52'    => link_to('export:/some/file.ext@52', export_url_with_rev_and_ext, :class => 'source download'),
      'export:/some/file@branch'    => link_to('export:/some/file@branch', export_url_with_branch, :class => 'source download'),
      # forum
      'forum#2'                     => link_to('Discussion', board_url, :class => 'board'),
      'forum:Discussion'            => link_to('Discussion', board_url, :class => 'board'),
      # message
      'message#4'                   => link_to('Post 2', message_url, :class => 'message'),
      'message#5'                   => link_to('RE: post 2', message_url.merge(:anchor => 'message-5', :r => 5), :class => 'message'),
      # news
      'news#1'                      => link_to('eCookbook first release !', news_url, :class => 'news'),
      'news:"eCookbook first release !"'        => link_to('eCookbook first release !', news_url, :class => 'news'),
      # project
      'project#3'                   => link_to('eCookbook Subproject 1', project_url, :class => 'project'),
      'project:subproject1'         => link_to('eCookbook Subproject 1', project_url, :class => 'project'),
      'project:"eCookbook subProject 1"'        => link_to('eCookbook Subproject 1', project_url, :class => 'project'),
      # not found
      '#0123456789'                 => '#0123456789',
      # invalid expressions
      'source:'                     => 'source:',
      # url hash
      "http://foo.bar/FAQ#3"        => '<a class="external" href="http://foo.bar/FAQ#3">http://foo.bar/FAQ#3</a>',
      # user
      'user:jsmith'                 => link_to_user(User.find_by_id(2)),
      'user:JSMITH'                 => link_to_user(User.find_by_id(2)),
      'user#2'                      => link_to_user(User.find_by_id(2)),
      '@jsmith'                     => link_to_user(User.find_by_id(2)),
      '@JSMITH'                     => link_to_user(User.find_by_id(2)),
      '@abcd@example.com'           => link_to_user(User.find_by_id(u_email_id)),
      'user:abcd@example.com'       => link_to_user(User.find_by_id(u_email_id)),
      '@foo.bar@example.com'        => link_to_user(User.find_by_id(u_email_id_2)),
      'user:foo.bar@example.com'    => link_to_user(User.find_by_id(u_email_id_2)),
      # invalid user
      'user:foobar'                 => 'user:foobar',
    }
    @project = Project.find(1)
    to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text), "#{text} failed" }
  end

  def test_link_to_note_within_the_same_page
    issue = Issue.find(1)
    assert_equal '<p><a href="#note-14">#note-14</a></p>', textilizable('#note-14', :object => issue)

    journal = Journal.find(2)
    assert_equal '<p><a href="#note-2">#note-2</a></p>', textilizable('#note-2', :object => journal)
  end

  def test_user_links_with_email_as_login_name_should_not_be_parsed_textile
    with_settings :text_formatting => 'textile' do
      u = User.generate!(:login => 'jsmith@somenet.foo')

      # user link format: @jsmith@somenet.foo
      raw = "@jsmith@somenet.foo should not be parsed in jsmith@somenet.foo"
      assert_match(
        %r{<p><a class="user active".*>#{u.name}</a> should not be parsed in <a class="email" href="mailto:jsmith@somenet.foo">jsmith@somenet.foo</a></p>},
        textilizable(raw, :project => Project.find(1)))

      # user link format: user:jsmith@somenet.foo
      raw = "user:jsmith@somenet.foo should not be parsed in jsmith@somenet.foo"
      assert_match(
        %r{<p><a class="user active".*>#{u.name}</a> should not be parsed in <a class="email" href="mailto:jsmith@somenet.foo">jsmith@somenet.foo</a></p>},
        textilizable(raw, :project => Project.find(1)))
    end
  end

  def test_user_links_with_email_as_login_name_should_not_be_parsed_markdown
    with_settings :text_formatting => 'markdown' do
      u = User.generate!(:login => 'jsmith@somenet.foo')

      # user link format: @jsmith@somenet.foo
      raw = "@jsmith@somenet.foo should not be parsed in jsmith@somenet.foo"
      assert_match(
        %r{<p><a class=\"user active\".*>#{u.name}</a> should not be parsed in <a href=\"mailto:jsmith@somenet.foo\">jsmith@somenet.foo</a></p>},
        textilizable(raw, :project => Project.find(1)))

      # user link format: user:jsmith@somenet.foo
      raw = "user:jsmith@somenet.foo should not be parsed in jsmith@somenet.foo"
      assert_match(
        %r{<p><a class=\"user active\".*>#{u.name}</a> should not be parsed in <a href=\"mailto:jsmith@somenet.foo\">jsmith@somenet.foo</a></p>},
        textilizable(raw, :project => Project.find(1)))
    end
  end

  def test_should_not_parse_redmine_links_inside_link
    raw = "r1 should not be parsed in http://example.com/url-r1/"
    assert_match(
      %r{<p><a class="changeset".*>r1</a> should not be parsed in <a class="external" href="http://example.com/url-r1/">http://example.com/url-r1/</a></p>},
      textilizable(raw, :project => Project.find(1)))
  end

  def test_redmine_links_with_a_different_project_before_current_project
    vp1 = Version.generate!(:project_id => 1, :name => '1.4.4')
    vp3 = Version.generate!(:project_id => 3, :name => '1.4.4')
    @project = Project.find(3)
    result1 = link_to("1.4.4", "/versions/#{vp1.id}", :class => "version")
    result2 = link_to("1.4.4", "/versions/#{vp3.id}", :class => "version")
    assert_equal "<p>#{result1} #{result2}</p>",
                 textilizable("ecookbook:version:1.4.4 version:1.4.4")
  end

  def test_escaped_redmine_links_should_not_be_parsed
    to_test = [
      '#3.',
      '#3-14.',
      '#3#-note14.',
      'r1',
      'document#1',
      'document:"Test document"',
      'version#2',
      'version:1.0',
      'version:"1.0"',
      'source:/some/file'
    ]
    @project = Project.find(1)
    to_test.each { |text| assert_equal "<p>#{text}</p>", textilizable("!" + text), "#{text} failed" }
  end

  def test_cross_project_redmine_links
    source_link = link_to('ecookbook:source:/some/file',
                          {:controller => 'repositories', :action => 'entry',
                           :id => 'ecookbook', :repository_id => 10, :path => ['some', 'file']},
                          :class => 'source')
    changeset_link = link_to('ecookbook:r2',
                             {:controller => 'repositories', :action => 'revision',
                              :id => 'ecookbook', :repository_id => 10, :rev => 2},
                             :class => 'changeset',
                             :title => 'This commit fixes #1, #2 and references #1 & #3')
    to_test = {
      # documents
      'document:"Test document"'              => 'document:"Test document"',
      'ecookbook:document:"Test document"'    =>
          link_to("Test document", "/documents/1", :class => "document"),
      'invalid:document:"Test document"'      => 'invalid:document:"Test document"',
      # versions
      'version:"1.0"'                         => 'version:"1.0"',
      'ecookbook:version:"1.0"'               =>
          link_to("1.0", "/versions/2", :class => "version"),
      'invalid:version:"1.0"'                 => 'invalid:version:"1.0"',
      # changeset
      'r2'                                    => 'r2',
      'ecookbook:r2'                          => changeset_link,
      'invalid:r2'                            => 'invalid:r2',
      # source
      'source:/some/file'                     => 'source:/some/file',
      'ecookbook:source:/some/file'           => source_link,
      'invalid:source:/some/file'             => 'invalid:source:/some/file',
    }
    @project = Project.find(3)
    to_test.each do |text, result|
      assert_equal "<p>#{result}</p>", textilizable(text), "#{text} failed"
    end
  end

  def test_redmine_links_by_name_should_work_with_html_escaped_characters
    v = Version.generate!(:name => "Test & Show.txt", :project_id => 1)
    link = link_to("Test & Show.txt", "/versions/#{v.id}", :class => "version")

    @project = v.project
    assert_equal "<p>#{link}</p>", textilizable('version:"Test & Show.txt"')
  end

  def test_link_to_issue_subject
    issue = Issue.generate!(:subject => "01234567890123456789")
    str = link_to_issue(issue, :truncate => 10)
    result = link_to("Bug ##{issue.id}", "/issues/#{issue.id}", :class => issue.css_classes)
    assert_equal "#{result}: 0123456...", str

    issue = Issue.generate!(:subject => "<&>")
    str = link_to_issue(issue)
    result = link_to("Bug ##{issue.id}", "/issues/#{issue.id}", :class => issue.css_classes)
    assert_equal "#{result}: &lt;&amp;&gt;", str

    issue = Issue.generate!(:subject => "<&>0123456789012345")
    str = link_to_issue(issue, :truncate => 10)
    result = link_to("Bug ##{issue.id}", "/issues/#{issue.id}", :class => issue.css_classes)
    assert_equal "#{result}: &lt;&amp;&gt;0123...", str
  end

  def test_link_to_issue_title
    long_str = "0123456789" * 5

    issue = Issue.generate!(:subject => "#{long_str}01234567890123456789")
    str = link_to_issue(issue, :subject => false)
    result = link_to("Bug ##{issue.id}", "/issues/#{issue.id}",
                     :class => issue.css_classes,
                     :title => "#{long_str}0123456...")
    assert_equal result, str

    issue = Issue.generate!(:subject => "<&>#{long_str}01234567890123456789")
    str = link_to_issue(issue, :subject => false)
    result = link_to("Bug ##{issue.id}", "/issues/#{issue.id}",
                     :class => issue.css_classes,
                     :title => "<&>#{long_str}0123...")
    assert_equal result, str
  end

  def test_multiple_repositories_redmine_links
    svn = Repository::Subversion.create!(:project_id => 1, :identifier => 'svn_repo-1', :url => 'file:///foo/hg')
    Changeset.create!(:repository => svn, :committed_on => Time.now, :revision => '123')
    hg = Repository::Mercurial.create!(:project_id => 1, :identifier => 'hg1', :url => '/foo/hg')
    Changeset.create!(:repository => hg, :committed_on => Time.now, :revision => '123', :scmid => 'abcd')

    changeset_link = link_to(
                       'r2',
                       {:controller => 'repositories', :action => 'revision',
                        :id => 'ecookbook', :repository_id => 10, :rev => 2},
                       :class => 'changeset',
                       :title => 'This commit fixes #1, #2 and references #1 & #3')
    svn_changeset_link = link_to(
                           'svn_repo-1|r123',
                           {:controller => 'repositories', :action => 'revision',
                            :id => 'ecookbook', :repository_id => 'svn_repo-1', :rev => 123},
                           :class => 'changeset', :title => '')
    hg_changeset_link = link_to(
                          'hg1|abcd',
                          {:controller => 'repositories', :action => 'revision',
                           :id => 'ecookbook', :repository_id => 'hg1', :rev => 'abcd'},
                          :class => 'changeset', :title => '')
    source_link = link_to('source:some/file',
                          {:controller => 'repositories', :action => 'entry',
                           :id => 'ecookbook', :repository_id => 10,
                           :path => ['some', 'file']},
                          :class => 'source')
    hg_source_link = link_to('source:hg1|some/file',
                             {:controller => 'repositories', :action => 'entry',
                              :id => 'ecookbook', :repository_id => 'hg1',
                              :path => ['some', 'file']},
                             :class => 'source')

    to_test = {
      'r2'                          => changeset_link,
      'svn_repo-1|r123'             => svn_changeset_link,
      'invalid|r123'                => 'invalid|r123',
      'commit:hg1|abcd'             => hg_changeset_link,
      'commit:invalid|abcd'         => 'commit:invalid|abcd',
      # source
      'source:some/file'            => source_link,
      'source:hg1|some/file'        => hg_source_link,
      'source:invalid|some/file'    => 'source:invalid|some/file',
    }

    @project = Project.find(1)
    to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text), "#{text} failed" }
  end

  def test_cross_project_multiple_repositories_redmine_links
    svn = Repository::Subversion.create!(:project_id => 1, :identifier => 'svn1', :url => 'file:///foo/hg')
    Changeset.create!(:repository => svn, :committed_on => Time.now, :revision => '123')
    hg = Repository::Mercurial.create!(:project_id => 1, :identifier => 'hg1', :url => '/foo/hg')
    Changeset.create!(:repository => hg, :committed_on => Time.now, :revision => '123', :scmid => 'abcd')

    changeset_link = link_to(
                       'ecookbook:r2',
                       {:controller => 'repositories', :action => 'revision',
                        :id => 'ecookbook', :repository_id => 10, :rev => 2},
                       :class => 'changeset',
                       :title => 'This commit fixes #1, #2 and references #1 & #3')
    svn_changeset_link = link_to(
                           'ecookbook:svn1|r123',
                           {:controller => 'repositories', :action => 'revision',
                            :id => 'ecookbook', :repository_id => 'svn1', :rev => 123},
                           :class => 'changeset', :title => '')
    hg_changeset_link = link_to(
                          'ecookbook:hg1|abcd',
                          {:controller => 'repositories', :action => 'revision',
                           :id => 'ecookbook', :repository_id => 'hg1', :rev => 'abcd'},
                          :class => 'changeset', :title => '')

    source_link = link_to('ecookbook:source:some/file',
                          {:controller => 'repositories', :action => 'entry',
                           :id => 'ecookbook', :repository_id => 10,
                           :path => ['some', 'file']}, :class => 'source')
    hg_source_link = link_to('ecookbook:source:hg1|some/file',
                             {:controller => 'repositories', :action => 'entry',
                              :id => 'ecookbook', :repository_id => 'hg1',
                              :path => ['some', 'file']}, :class => 'source')
    to_test = {
      'ecookbook:r2'                           => changeset_link,
      'ecookbook:svn1|r123'                    => svn_changeset_link,
      'ecookbook:invalid|r123'                 => 'ecookbook:invalid|r123',
      'ecookbook:commit:hg1|abcd'              => hg_changeset_link,
      'ecookbook:commit:invalid|abcd'          => 'ecookbook:commit:invalid|abcd',
      'invalid:commit:invalid|abcd'            => 'invalid:commit:invalid|abcd',
      # source
      'ecookbook:source:some/file'             => source_link,
      'ecookbook:source:hg1|some/file'         => hg_source_link,
      'ecookbook:source:invalid|some/file'     => 'ecookbook:source:invalid|some/file',
      'invalid:source:invalid|some/file'       => 'invalid:source:invalid|some/file',
    }
    @project = Project.find(3)
    to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text), "#{text} failed" }
  end

  def test_redmine_links_git_commit
    @project = Project.find(3)
    r = Repository::Git.create!(:project => @project, :url => '/tmp/test/git')
    c = Changeset.create!(
                      :repository => r,
                      :committed_on => Time.now,
                      :revision => 'abcd',
                      :scmid => 'abcd',
                      :comments => 'test commit')
    changeset_link = link_to('abcd',
                             {
                                 :controller => 'repositories',
                                 :action     => 'revision',
                                 :id         => 'subproject1',
                                 :repository_id => r.id,
                                 :rev        => 'abcd',
                              },
                             :class => 'changeset', :title => 'test commit')
    to_test = {
      'commit:abcd' => changeset_link,
     }
    to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text) }
  end

  # TODO: Bazaar commit id contains mail address, so it contains '@' and '_'.
  def test_redmine_links_mercurial_commit
    @project = Project.find(3)
    r = Repository::Mercurial.create!(:project => @project, :url => '/tmp/test')
    c = Changeset.create!(
                      :repository => r,
                      :committed_on => Time.now,
                      :revision => '123',
                      :scmid => 'abcd',
                      :comments => 'test commit')
    changeset_link_rev = link_to(
                              'r123',
                              {
                                     :controller => 'repositories',
                                     :action     => 'revision',
                                     :id         => 'subproject1',
                                     :repository_id => r.id,
                                     :rev        => '123',
                              },
                              :class => 'changeset', :title => 'test commit')
    changeset_link_commit = link_to(
                              'abcd',
                              {
                                    :controller => 'repositories',
                                    :action     => 'revision',
                                    :id         => 'subproject1',
                                    :repository_id => r.id,
                                    :rev        => 'abcd',
                              },
                              :class => 'changeset', :title => 'test commit')
    to_test = {
      'r123' => changeset_link_rev,
      'commit:abcd' => changeset_link_commit,
     }
    to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text) }
  end

  def test_attachment_links
    text = 'attachment:error281.txt'
    result = link_to("error281.txt", "/attachments/1",
                     :class => "attachment")
    assert_equal "<p>#{result}</p>",
                 textilizable(text,
                              :attachments => Issue.find(3).attachments),
                 "#{text} failed"
  end

  def test_attachment_link_should_link_to_latest_attachment
    a1 = Attachment.generate!(:filename => "test.txt", :created_on => 1.hour.ago)
    a2 = Attachment.generate!(:filename => "test.txt")
    result = link_to("test.txt", "/attachments/#{a2.id}",
                     :class => "attachment")
    assert_equal "<p>#{result}</p>",
                 textilizable('attachment:test.txt', :attachments => [a1, a2])
  end

  def test_attachment_links_to_images_with_email_format_should_not_be_parsed
    attachment = Attachment.generate!(:filename => 'image@2x.png')
    with_settings :text_formatting => 'textile' do
      raw = "attachment:image@2x.png should not be parsed in image@2x.png"
      assert_match(
        %r{<p><a class="attachment" href="/attachments/#{attachment.id}">image@2x.png</a> should not be parsed in image@2x.png</p>},
        textilizable(raw, :attachments => [attachment]))
    end
    with_settings :text_formatting => 'markdown' do
      raw = "attachment:image@2x.png should not be parsed in image@2x.png"
      assert_match(
        %r{<p><a class="attachment" href="/attachments/#{attachment.id}">image@2x.png</a> should not be parsed in image@2x.png</p>},
        textilizable(raw, :attachments => [attachment]))
    end
  end

  def test_wiki_links
    User.current = User.find_by_login('jsmith')
    russian_eacape = CGI.escape(@russian_test)
    to_test = {
      '[[CookBook documentation]]' =>
          link_to("CookBook documentation",
                  "/projects/ecookbook/wiki/CookBook_documentation",
                  :class => "wiki-page"),
      '[[Another page|Page]]' =>
          link_to("Page",
                  "/projects/ecookbook/wiki/Another_page",
                  :class => "wiki-page"),
      # title content should be formatted
      '[[Another page|With _styled_ *title*]]' =>
          link_to("With <em>styled</em> <strong>title</strong>".html_safe,
                  "/projects/ecookbook/wiki/Another_page",
                  :class => "wiki-page"),
      '[[Another page|With title containing <strong>HTML entities &amp; markups</strong>]]' =>
          link_to("With title containing &lt;strong&gt;HTML entities &amp; markups&lt;/strong&gt;".html_safe,
                  "/projects/ecookbook/wiki/Another_page",
                  :class => "wiki-page"),
      # link with anchor
      '[[CookBook documentation#One-section]]' =>
          link_to("CookBook documentation",
                  "/projects/ecookbook/wiki/CookBook_documentation#One-section",
                  :class => "wiki-page"),
      '[[Another page#anchor|Page]]' =>
          link_to("Page",
                  "/projects/ecookbook/wiki/Another_page#anchor",
                  :class => "wiki-page"),
      # UTF8 anchor
      "[[Another_page##{@russian_test}|#{@russian_test}]]" =>
          link_to(@russian_test,
                  "/projects/ecookbook/wiki/Another_page##{russian_eacape}",
                  :class => "wiki-page"),
      # link to anchor
      '[[#anchor]]' =>
          link_to("#anchor",
                  "#anchor",
                  :class => "wiki-page"),
      '[[#anchor|One-section]]' =>
          link_to("One-section",
                  "#anchor",
                  :class => "wiki-page"),
      # page that doesn't exist
      '[[Unknown page]]' =>
          link_to("Unknown page",
                  "/projects/ecookbook/wiki/Unknown_page",
                  :class => "wiki-page new"),
      '[[Unknown page|404]]' =>
          link_to("404",
                  "/projects/ecookbook/wiki/Unknown_page",
                  :class => "wiki-page new"),
      # link to another project wiki
      '[[onlinestore:]]' =>
          link_to("onlinestore",
                  "/projects/onlinestore/wiki",
                  :class => "wiki-page"),
      '[[onlinestore:|Wiki]]' =>
          link_to("Wiki",
                  "/projects/onlinestore/wiki",
                  :class => "wiki-page"),
      '[[onlinestore:Start page]]' =>
          link_to("Start page",
                  "/projects/onlinestore/wiki/Start_page",
                  :class => "wiki-page"),
      '[[onlinestore:Start page|Text]]' =>
          link_to("Text",
                  "/projects/onlinestore/wiki/Start_page",
                  :class => "wiki-page"),
      '[[onlinestore:Unknown page]]' =>
          link_to("Unknown page",
                  "/projects/onlinestore/wiki/Unknown_page",
                  :class => "wiki-page new"),
      # struck through link
      '-[[Another page|Page]]-' =>
          "<del>".html_safe +
            link_to("Page",
                    "/projects/ecookbook/wiki/Another_page",
                    :class => "wiki-page").html_safe +
            "</del>".html_safe,
      '-[[Another page|Page]] link-' =>
          "<del>".html_safe +
            link_to("Page",
                    "/projects/ecookbook/wiki/Another_page",
                    :class => "wiki-page").html_safe +
            " link</del>".html_safe,
      # escaping
      '![[Another page|Page]]' => '[[Another page|Page]]',
      # project does not exist
      '[[unknowproject:Start]]' => '[[unknowproject:Start]]',
      '[[unknowproject:Start|Page title]]' => '[[unknowproject:Start|Page title]]',
      # missing permission to view wiki in project
      '[[private-child:]]' => '[[private-child:]]',
      '[[private-child:Wiki]]' => '[[private-child:Wiki]]',
    }
    @project = Project.find(1)
    to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text) }
  end

  def test_wiki_links_with_special_characters_should_work_in_textile
    to_test = wiki_links_with_special_characters

    @project = Project.find(1)
    with_settings :text_formatting => 'textile' do
      to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text) }
    end
  end

  def test_wiki_links_with_special_characters_should_work_in_markdown
    to_test = wiki_links_with_special_characters

    @project = Project.find(1)
    with_settings :text_formatting => 'markdown' do
      to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text).strip }
    end
  end

  def test_wiki_links_with_square_brackets_in_project_name
    User.current = User.find_by_login('jsmith')

    another_project = Project.find(1) # eCookbook
    another_project.name = "[foo]#{another_project.name}"
    another_project.save

    page = another_project.wiki.find_page('Another page')
    page.title = "[bar]#{page.title}"
    page.save

    to_test = {
      '[[[foo]eCookbook:]]' =>
          link_to("[foo]eCookbook",
                  "/projects/ecookbook/wiki",
                  :class => "wiki-page"),
      '[[[foo]eCookbook:CookBook documentation]]' =>
          link_to("CookBook documentation",
                  "/projects/ecookbook/wiki/CookBook_documentation",
                  :class => "wiki-page"),
      '[[[foo]eCookbook:[bar]Another page]]' =>
          link_to("[bar]Another page",
                  "/projects/ecookbook/wiki/%5Bbar%5DAnother_page",
                  :class => "wiki-page"),
      '[[[foo]eCookbook:Unknown page]]' =>
          link_to("Unknown page",
                  "/projects/ecookbook/wiki/Unknown_page",
                  :class => "wiki-page new"),
      '[[[foo]eCookbook:[baz]Unknown page]]' =>
          link_to("[baz]Unknown page",
                  "/projects/ecookbook/wiki/%5Bbaz%5DUnknown_page",
                  :class => "wiki-page new"),
    }
    @project = Project.find(2)  # OnlineStore
    with_settings :text_formatting => 'textile' do
      to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text) }
    end
    with_settings :text_formatting => 'markdown' do
      to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text).strip }
    end
  end

  def test_wiki_links_within_local_file_generation_context
    to_test = {
      # link to a page
      '[[CookBook documentation]]' =>
         link_to("CookBook documentation", "CookBook_documentation.html",
                 :class => "wiki-page"),
      '[[CookBook documentation|documentation]]' =>
         link_to("documentation", "CookBook_documentation.html",
                 :class => "wiki-page"),
      '[[CookBook documentation#One-section]]' =>
         link_to("CookBook documentation", "CookBook_documentation.html#One-section",
                 :class => "wiki-page"),
      '[[CookBook documentation#One-section|documentation]]' =>
         link_to("documentation", "CookBook_documentation.html#One-section",
                 :class => "wiki-page"),
      # page that doesn't exist
      '[[Unknown page]]' =>
         link_to("Unknown page", "Unknown_page.html",
                 :class => "wiki-page new"),
      '[[Unknown page|404]]' =>
         link_to("404", "Unknown_page.html",
                 :class => "wiki-page new"),
      '[[Unknown page#anchor]]' =>
         link_to("Unknown page", "Unknown_page.html#anchor",
                 :class => "wiki-page new"),
      '[[Unknown page#anchor|404]]' =>
         link_to("404", "Unknown_page.html#anchor",
                 :class => "wiki-page new"),
    }
    @project = Project.find(1)
    to_test.each do |text, result|
      assert_equal "<p>#{result}</p>", textilizable(text, :wiki_links => :local)
    end
  end

  def test_wiki_links_within_wiki_page_context
    page = WikiPage.find_by_title('Another_page' )
    to_test = {
      '[[CookBook documentation]]' =>
         link_to("CookBook documentation",
                 "/projects/ecookbook/wiki/CookBook_documentation",
                 :class => "wiki-page"),
      '[[CookBook documentation|documentation]]' =>
         link_to("documentation",
                 "/projects/ecookbook/wiki/CookBook_documentation",
                 :class => "wiki-page"),
      '[[CookBook documentation#One-section]]' =>
         link_to("CookBook documentation",
                 "/projects/ecookbook/wiki/CookBook_documentation#One-section",
                 :class => "wiki-page"),
      '[[CookBook documentation#One-section|documentation]]' =>
         link_to("documentation",
                 "/projects/ecookbook/wiki/CookBook_documentation#One-section",
                 :class => "wiki-page"),
      # link to the current page
      '[[Another page]]' =>
         link_to("Another page",
                 "/projects/ecookbook/wiki/Another_page",
                 :class => "wiki-page"),
      '[[Another page|Page]]' =>
         link_to("Page",
                 "/projects/ecookbook/wiki/Another_page",
                 :class => "wiki-page"),
      '[[Another page#anchor]]' =>
         link_to("Another page",
                 "#anchor",
                 :class => "wiki-page"),
      '[[Another page#anchor|Page]]' =>
         link_to("Page",
                 "#anchor",
                 :class => "wiki-page"),
      # page that doesn't exist
      '[[Unknown page]]' =>
         link_to("Unknown page",
                 "/projects/ecookbook/wiki/Unknown_page?parent=Another_page",
                 :class => "wiki-page new"),
      '[[Unknown page|404]]' =>
         link_to("404",
                 "/projects/ecookbook/wiki/Unknown_page?parent=Another_page",
                 :class => "wiki-page new"),
      '[[Unknown page#anchor]]' =>
         link_to("Unknown page",
                 "/projects/ecookbook/wiki/Unknown_page?parent=Another_page#anchor",
                 :class => "wiki-page new"),
      '[[Unknown page#anchor|404]]' =>
         link_to("404",
                 "/projects/ecookbook/wiki/Unknown_page?parent=Another_page#anchor",
                 :class => "wiki-page new"),
    }
    @project = Project.find(1)
    to_test.each do |text, result|
      assert_equal "<p>#{result}</p>",
                   textilizable(WikiContent.new( :text => text, :page => page ), :text)
    end
  end

  def test_wiki_links_anchor_option_should_prepend_page_title_to_href
    to_test = {
      # link to a page
      '[[CookBook documentation]]' =>
          link_to("CookBook documentation",
                  "#CookBook_documentation",
                  :class => "wiki-page"),
      '[[CookBook documentation|documentation]]' =>
          link_to("documentation",
                  "#CookBook_documentation",
                  :class => "wiki-page"),
      '[[CookBook documentation#One-section]]' =>
          link_to("CookBook documentation",
                  "#CookBook_documentation_One-section",
                  :class => "wiki-page"),
      '[[CookBook documentation#One-section|documentation]]' =>
          link_to("documentation",
                  "#CookBook_documentation_One-section",
                  :class => "wiki-page"),
      # page that doesn't exist
      '[[Unknown page]]' =>
          link_to("Unknown page",
                  "#Unknown_page",
                  :class => "wiki-page new"),
      '[[Unknown page|404]]' =>
          link_to("404",
                  "#Unknown_page",
                  :class => "wiki-page new"),
      '[[Unknown page#anchor]]' =>
          link_to("Unknown page",
                  "#Unknown_page_anchor",
                  :class => "wiki-page new"),
      '[[Unknown page#anchor|404]]' =>
          link_to("404",
                  "#Unknown_page_anchor",
                  :class => "wiki-page new"),
    }
    @project = Project.find(1)
    to_test.each do |text, result|
      assert_equal "<p>#{result}</p>", textilizable(text, :wiki_links => :anchor)
    end
  end

  def test_html_tags
    to_test = {
      "<div>content</div>" => "<p>&lt;div&gt;content&lt;/div&gt;</p>",
      "<div class=\"bold\">content</div>" => "<p>&lt;div class=\"bold\"&gt;content&lt;/div&gt;</p>",
      "<script>some script;</script>" => "<p>&lt;script&gt;some script;&lt;/script&gt;</p>",
      # do not escape pre/code tags
      "<pre>\nline 1\nline2</pre>" => "<pre>\nline 1\nline2</pre>",
      "<pre><code>\nline 1\nline2</code></pre>" => "<pre><code>\nline 1\nline2</code></pre>",
      "<pre><div>content</div></pre>" => "<pre>&lt;div&gt;content&lt;/div&gt;</pre>",
      "HTML comment: <!-- no comments -->" => "<p>HTML comment: &lt;!-- no comments --&gt;</p>",
      "<!-- opening comment" => "<p>&lt;!-- opening comment</p>",
      # remove attributes including class
      "<pre class='foo'>some text</pre>" => "<pre>some text</pre>",
      '<pre class="foo">some text</pre>' => '<pre>some text</pre>',
      "<pre class='foo bar'>some text</pre>" => "<pre>some text</pre>",
      '<pre class="foo bar">some text</pre>' => '<pre>some text</pre>',
      "<pre onmouseover='alert(1)'>some text</pre>" => "<pre>some text</pre>",
      # xss
      '<pre><code class=""onmouseover="alert(1)">text</code></pre>' => '<pre><code>text</code></pre>',
      '<pre class=""onmouseover="alert(1)">text</pre>' => '<pre>text</pre>',
    }
    to_test.each { |text, result| assert_equal result, textilizable(text) }
  end

  def test_allowed_html_tags
    to_test = {
      "<pre>preformatted text</pre>" => "<pre>preformatted text</pre>",
      "<notextile>no *textile* formatting</notextile>" => "no *textile* formatting",
      "<notextile>this is <tag>a tag</tag></notextile>" => "this is &lt;tag&gt;a tag&lt;/tag&gt;"
    }
    to_test.each { |text, result| assert_equal result, textilizable(text) }
  end

  def test_pre_tags
    raw = <<~RAW
      Before

      <pre>
      <prepared-statement-cache-size>32</prepared-statement-cache-size>
      </pre>

      After
    RAW
    expected = <<~EXPECTED
      <p>Before</p>
      <pre>
      &lt;prepared-statement-cache-size&gt;32&lt;/prepared-statement-cache-size&gt;
      </pre>
      <p>After</p>
    EXPECTED
    assert_equal expected.gsub(%r{[\r\n\t]}, ''), textilizable(raw).gsub(%r{[\r\n\t]}, '')
  end

  def test_pre_content_should_not_parse_wiki_and_redmine_links
    raw = <<~RAW
      [[CookBook documentation]]

      #1

      <pre>
      [[CookBook documentation]]

      #1
      </pre>
    RAW
    result1 = link_to("CookBook documentation",
                      "/projects/ecookbook/wiki/CookBook_documentation",
                      :class => "wiki-page")
    result2 = link_to('#1',
                      "/issues/1",
                      :class => Issue.find(1).css_classes,
                      :title => "Bug: Cannot print recipes (New)")
    expected = <<~EXPECTED
      <p>#{result1}</p>
      <p>#{result2}</p>
      <pre>
      [[CookBook documentation]]

      #1
      </pre>
    EXPECTED
    @project = Project.find(1)
    assert_equal expected.gsub(%r{[\r\n\t]}, ''), textilizable(raw).gsub(%r{[\r\n\t]}, '')
  end

  def test_non_closing_pre_blocks_should_be_closed
    raw = <<~RAW
      <pre><code>
    RAW
    expected = <<~EXPECTED
      <pre><code>
      </code></pre>
    EXPECTED
    @project = Project.find(1)
    assert_equal expected.gsub(%r{[\r\n\t]}, ''), textilizable(raw).gsub(%r{[\r\n\t]}, '')
  end

  def test_unbalanced_closing_pre_tag_should_not_error
    assert_nothing_raised do
      textilizable("unbalanced</pre>")
    end
  end

  def test_syntax_highlight
    raw = <<~RAW
      <pre><code class="ECMA_script">
      /* Hello */
      document.write("Hello World!");
      </code></pre>
    RAW
    expected = <<~EXPECTED
      <pre><code class="ECMA_script syntaxhl"><span class="cm">/* Hello */</span><span class="nb">document</span><span class="p">.</span><span class="nx">write</span><span class="p">(</span><span class="dl">"</span><span class="s2">Hello World!</span><span class="dl">"</span><span class="p">);</span></code></pre>
    EXPECTED
    assert_equal expected.gsub(%r{[\r\n\t]}, ''), textilizable(raw).gsub(%r{[\r\n\t]}, '')
  end

  def test_syntax_highlight_ampersand_in_textile
    raw = <<~RAW
      <pre><code class="ruby">
      x = a & b
      </code></pre>
    RAW
    expected = <<~EXPECTED
      <pre><code class=\"ruby syntaxhl\"><span class=\"n\">x</span> <span class=\"o\">=</span> <span class=\"n\">a</span> <span class=\"o\">&amp;</span> <span class=\"n\">b</span></code></pre>
    EXPECTED
    with_settings :text_formatting => 'textile' do
      assert_equal expected.gsub(%r{[\r\n\t]}, ''), textilizable(raw).gsub(%r{[\r\n\t]}, '')
    end
  end

  def test_syntax_highlight_should_normalize_line_endings
    assert_equal "line 1\nline 2\n", syntax_highlight("test.txt", "line 1\rline 2\r\n")
  end

  def test_to_path_param
    assert_equal 'test1/test2', to_path_param('test1/test2')
    assert_equal 'test1/test2', to_path_param('/test1/test2/')
    assert_equal 'test1/test2', to_path_param('//test1/test2/')
    assert_nil to_path_param('/')
  end

  def test_wiki_links_in_tables
    text = "|[[Page|Link title]]|[[Other Page|Other title]]|\n|Cell 21|[[Last page]]|"
    link1 = link_to("Link title", "/projects/ecookbook/wiki/Page", :class => "wiki-page new")
    link2 = link_to("Other title", "/projects/ecookbook/wiki/Other_Page", :class => "wiki-page new")
    link3 = link_to("Last page", "/projects/ecookbook/wiki/Last_page", :class => "wiki-page new")
    result = "<tr><td>#{link1}</td>" +
               "<td>#{link2}</td>" +
               "</tr><tr><td>Cell 21</td><td>#{link3}</td></tr>"
    @project = Project.find(1)
    assert_equal "<table>#{result}</table>", textilizable(text).gsub(/[\t\n]/, '')
  end

  def test_text_formatting
    to_test = {'*_+bold, italic and underline+_*' => '<strong><em><ins>bold, italic and underline</ins></em></strong>',
               '(_text within parentheses_)' => '(<em>text within parentheses</em>)',
               'a *Humane Web* Text Generator' => 'a <strong>Humane Web</strong> Text Generator',
               'a H *umane* W *eb* T *ext* G *enerator*' => 'a H <strong>umane</strong> W <strong>eb</strong> T <strong>ext</strong> G <strong>enerator</strong>',
               'a *H* umane *W* eb *T* ext *G* enerator' => 'a <strong>H</strong> umane <strong>W</strong> eb <strong>T</strong> ext <strong>G</strong> enerator',
              }
    to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text) }
  end

  def test_wiki_horizontal_rule
    assert_equal '<hr />', textilizable('---')
    assert_equal '<p>Dashes: ---</p>', textilizable('Dashes: ---')
  end

  def test_headings
    raw = 'h1. Some heading'
    expected = %|<a name="Some-heading"></a>\n<h1 >Some heading<a href="#Some-heading" class="wiki-anchor">&para;</a></h1>|

    assert_equal expected, textilizable(raw)
  end

  def test_headings_with_special_chars
    # This test makes sure that the generated anchor names match the expected
    # ones even if the heading text contains unconventional characters
    raw = 'h1. Some heading related to version 0.5'
    anchor = sanitize_anchor_name("Some-heading-related-to-version-0.5")
    expected = %|<a name="#{anchor}"></a>\n<h1 >Some heading related to version 0.5<a href="##{anchor}" class="wiki-anchor">&para;</a></h1>|

    assert_equal expected, textilizable(raw)
  end

  def test_headings_in_wiki_single_page_export_should_be_prepended_with_page_title
    page = WikiPage.new( :title => 'Page Title', :wiki_id => 1 )
    content = WikiContent.new( :text => 'h1. Some heading', :page => page )

    expected = %|<a name="Page_Title_Some-heading"></a>\n<h1 >Some heading<a href="#Page_Title_Some-heading" class="wiki-anchor">&para;</a></h1>|

    assert_equal expected, textilizable(content, :text, :wiki_links => :anchor )
  end

  def test_table_of_content
    set_language_if_valid 'en'
    raw = <<~RAW
      {{toc}}

      h1. Title

      Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Maecenas sed libero.

      h2. Subtitle with a [[Wiki]] link

      Nullam commodo metus accumsan nulla. Curabitur lobortis dui id dolor.

      h2. Subtitle with [[Wiki|another Wiki]] link

      h2. Subtitle with %{color:red}red text%

      <pre>
      some code
      </pre>

      h3. Subtitle with *some* _modifiers_

      h3. Subtitle with @inline code@

      h1. Another title

      h3. An "Internet link":http://www.redmine.org/ inside subtitle

      h2. "Project Name !/attachments/1234/logo_small.gif! !/attachments/5678/logo_2.png!":/projects/projectname/issues

    RAW
    expected =  '<ul class="toc">' +
                  '<li><strong>Table of contents</strong></li>' +
                  '<li><a href="#Title">Title</a>' +
                    '<ul>' +
                      '<li><a href="#Subtitle-with-a-Wiki-link">Subtitle with a Wiki link</a></li>' +
                      '<li><a href="#Subtitle-with-another-Wiki-link">Subtitle with another Wiki link</a></li>' +
                      '<li><a href="#Subtitle-with-red-text">Subtitle with red text</a>' +
                        '<ul>' +
                          '<li><a href="#Subtitle-with-some-modifiers">Subtitle with some modifiers</a></li>' +
                          '<li><a href="#Subtitle-with-inline-code">Subtitle with inline code</a></li>' +
                        '</ul>' +
                      '</li>' +
                    '</ul>' +
                  '</li>' +
                  '<li><a href="#Another-title">Another title</a>' +
                    '<ul>' +
                      '<li>' +
                        '<ul>' +
                          '<li><a href="#An-Internet-link-inside-subtitle">An Internet link inside subtitle</a></li>' +
                        '</ul>' +
                      '</li>' +
                      '<li><a href="#Project-Name">Project Name</a></li>' +
                    '</ul>' +
                  '</li>' +
               '</ul>'

    @project = Project.find(1)
    assert textilizable(raw).gsub("\n", "").include?(expected)
  end

  def test_table_of_content_should_generate_unique_anchors
    set_language_if_valid 'en'
    raw = <<~RAW
      {{toc}}

      h1. Title

      h2. Subtitle

      h2. Subtitle
    RAW
    expected =  '<ul class="toc">' +
                  '<li><strong>Table of contents</strong></li>' +
                  '<li><a href="#Title">Title</a>' +
                    '<ul>' +
                      '<li><a href="#Subtitle">Subtitle</a></li>' +
                      '<li><a href="#Subtitle-2">Subtitle</a></li>' +
                    '</ul>' +
                  '</li>' +
                '</ul>'
    @project = Project.find(1)
    result = textilizable(raw).gsub("\n", "")
    assert_include expected, result
    assert_include '<a name="Subtitle">', result
    assert_include '<a name="Subtitle-2">', result
  end

  def test_table_of_content_should_contain_included_page_headings
    set_language_if_valid 'en'
    raw = <<~RAW
      {{toc}}

      h1. Included

      {{include(Child_1)}}
    RAW
    expected = '<ul class="toc">' +
               '<li><strong>Table of contents</strong></li>' +
               '<li><a href="#Included">Included</a></li>' +
               '<li><a href="#Child-page-1">Child page 1</a></li>' +
               '</ul>'
    @project = Project.find(1)
    assert textilizable(raw).gsub("\n", "").include?(expected)
  end

  def test_toc_with_textile_formatting_should_be_parsed
    with_settings :text_formatting => 'textile' do
      assert_select_in textilizable("{{toc}}\n\nh1. Heading"), 'ul.toc li', :text => 'Heading'
      assert_select_in textilizable("{{<toc}}\n\nh1. Heading"), 'ul.toc.left li', :text => 'Heading'
      assert_select_in textilizable("{{>toc}}\n\nh1. Heading"), 'ul.toc.right li', :text => 'Heading'
    end
  end

  if Object.const_defined?(:Redcarpet)
  def test_toc_with_markdown_formatting_should_be_parsed
    with_settings :text_formatting => 'markdown' do
      assert_select_in textilizable("{{toc}}\n\n# Heading"), 'ul.toc li', :text => 'Heading'
      assert_select_in textilizable("{{<toc}}\n\n# Heading"), 'ul.toc.left li', :text => 'Heading'
      assert_select_in textilizable("{{>toc}}\n\n# Heading"), 'ul.toc.right li', :text => 'Heading'
    end
  end
  end

  def test_section_edit_links
    raw = <<~RAW
      h1. Title

      Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Maecenas sed libero.

      h2. Subtitle with a [[Wiki]] link

      h2. Subtitle with *some* _modifiers_

      h2. Subtitle with @inline code@

      <pre>
      some code

      h2. heading inside pre

      <h2>html heading inside pre</h2>
      </pre>

      h2. Subtitle after pre tag
    RAW
    @project = Project.find(1)
    set_language_if_valid 'en'
    result = textilizable(
               raw,
               :edit_section_links =>
                 {:controller => 'wiki', :action => 'edit',
                  :project_id => '1', :id => 'Test'}
             ).gsub("\n", "")
    # heading that contains inline code
    assert_match(
      Regexp.new('<div class="contextual heading-2" title="Edit this section" id="section-4">' +
      '<a class="icon-only icon-edit" href="/projects/1/wiki/Test/edit\?section=4">Edit this section</a></div>' +
      '<a name="Subtitle-with-inline-code"></a>' +
      '<h2 >Subtitle with <code>inline code</code><a href="#Subtitle-with-inline-code" class="wiki-anchor">&para;</a></h2>'),
      result)
    # last heading
    assert_match(
      Regexp.new('<div class="contextual heading-2" title="Edit this section" id="section-5">' +
      '<a class="icon-only icon-edit" href="/projects/1/wiki/Test/edit\?section=5">Edit this section</a></div>' +
      '<a name="Subtitle-after-pre-tag"></a>' +
      '<h2 >Subtitle after pre tag<a href="#Subtitle-after-pre-tag" class="wiki-anchor">&para;</a></h2>'),
      result)
  end

  def test_default_formatter
    with_settings :text_formatting => 'unknown' do
      text = 'a *link*: http://www.example.net/'
      assert_equal '<p>a *link*: <a class="external" href="http://www.example.net/">http://www.example.net/</a></p>', textilizable(text)
    end
  end

  def test_textilizable_with_formatting_set_to_false_should_not_format_text
    assert_equal '*text*', textilizable("*text*", :formatting => false)
  end

  def test_textilizable_with_formatting_set_to_true_should_format_text
    assert_equal '<p><strong>text</strong></p>', textilizable("*text*", :formatting => true)
  end

  def test_parse_redmine_links_should_handle_a_tag_without_attributes
    text = +'<a>http://example.com</a>'
    expected = text.dup
    parse_redmine_links(text, nil, nil, nil, true, {})
    assert_equal expected, text
  end

  def test_due_date_distance_in_words
    to_test = { Date.today => 'Due in 0 days',
                Date.today + 1 => 'Due in 1 day',
                Date.today + 100 => 'Due in about 3 months',
                Date.today + 20000 => 'Due in over 54 years',
                Date.today - 1 => '1 day late',
                Date.today - 100 => 'about 3 months late',
                Date.today - 20000 => 'over 54 years late',
               }
    ::I18n.locale = :en
    to_test.each do |date, expected|
      assert_equal expected, due_date_distance_in_words(date)
    end
  end

  def test_render_page_hierarchy
    parent_page = WikiPage.find(1)
    child_page = WikiPage.find_by(parent_id: parent_page.id)
    pages_by_parent_id = { nil => [parent_page], parent_page.id => [child_page] }
    result = render_page_hierarchy(pages_by_parent_id, nil)
    assert_select_in(
      result, 'ul.pages-hierarchy li a[href=?]',
      project_wiki_page_path(project_id: parent_page.project,
                             id: parent_page.title, version: nil))
    assert_select_in(
      result, 'ul.pages-hierarchy li ul.pages-hierarchy a[href=?]',
      project_wiki_page_path(project_id: child_page.project,
                             id: child_page.title, version: nil))
  end

  def test_render_page_hierarchy_with_timestamp
    parent_page = WikiPage.find(1)
    child_page = WikiPage.find_by(parent_id: parent_page.id)
    pages_by_parent_id = { nil => [parent_page], parent_page.id => [child_page] }
    result = render_page_hierarchy(pages_by_parent_id, nil, :timestamp => true)
    assert_select_in(
      result, 'ul.pages-hierarchy li a[title=?]',
      l(:label_updated_time,
        distance_of_time_in_words(Time.now, parent_page.updated_on)))
    assert_select_in(
      result, 'ul.pages-hierarchy li ul.pages-hierarchy a[title=?]',
      l(:label_updated_time,
        distance_of_time_in_words(Time.now, child_page.updated_on)))
  end

  def test_render_page_hierarchy_when_action_is_export
    parent_page = WikiPage.find(1)
    child_page = WikiPage.find_by(parent_id: parent_page.id)
    pages_by_parent_id = { nil => [parent_page], parent_page.id => [child_page] }

    # Change controller and action using stub
    controller.stubs(:controller_name).returns('wiki')
    controller.stubs(:action_name).returns("export")

    result = render_page_hierarchy(pages_by_parent_id, nil)
    assert_select_in result, 'ul.pages-hierarchy li a[href=?]', "##{parent_page.title}"
    assert_select_in result, 'ul.pages-hierarchy li ul.pages-hierarchy a[href=?]', "##{child_page.title}"
  end

  def test_link_to_user
    user = User.find(2)
    result = link_to("John Smith", "/users/2", :class => "user active")
    assert_equal result, link_to_user(user)
  end

  def test_link_to_user_should_not_link_to_locked_user
    with_current_user nil do
      user = User.find(5)
      assert user.locked?
      assert_equal 'Dave2 Lopper2', link_to_user(user)
    end
  end

  def test_link_to_user_should_link_to_locked_user_if_current_user_is_admin
    with_current_user User.find(1) do
      user = User.find(5)
      assert user.locked?
      result = link_to("Dave2 Lopper2", "/users/5", :class => "user locked")
      assert_equal result, link_to_user(user)
    end
  end

  def test_link_to_group_should_return_only_group_name_for_non_admin_users
    User.current = nil
    group = Group.find(10)
    assert_equal "A Team", link_to_group(group)
  end

  def test_link_to_group_should_link_to_group_edit_page_for_admin_users
    User.current = User.find(1)
    group = Group.find(10)
    result = link_to("A Team", "/groups/10/edit")
    assert_equal result, link_to_group(group)
  end

  def test_link_to_user_should_not_link_to_anonymous
    user = User.anonymous
    assert user.anonymous?
    t = link_to_user(user)
    assert_equal ::I18n.t(:label_user_anonymous), t
  end

  def test_link_to_attachment
    a = Attachment.find(3)
    assert_equal(
      '<a href="/attachments/3">logo.gif</a>',
      link_to_attachment(a))
    assert_equal(
      '<a href="/attachments/3">Text</a>',
      link_to_attachment(a, :text => 'Text'))
    result = link_to("logo.gif", "/attachments/3", :class => "foo")
    assert_equal(
      result,
      link_to_attachment(a, :class => 'foo'))
    assert_equal(
      '<a href="/attachments/download/3/logo.gif">logo.gif</a>',
      link_to_attachment(a, :download => true))
    assert_equal(
      '<a href="http://test.host/attachments/3">logo.gif</a>',
      link_to_attachment(a, :only_path => false))
  end

  def test_thumbnail_tag
    a = Attachment.find(3)
    assert_select_in(
      thumbnail_tag(a),
      'a[href=?][title=?] img[src=?]',
      "/attachments/3", "logo.gif", "/attachments/thumbnail/3")
  end

  def test_link_to_project
    project = Project.find(1)
    assert_equal %(<a href="/projects/ecookbook">eCookbook</a>),
                 link_to_project(project)
    assert_equal %(<a href="http://test.host/projects/ecookbook?jump=blah">eCookbook</a>),
                 link_to_project(project, {:only_path => false, :jump => 'blah'})
  end

  def test_link_to_project_settings
    project = Project.find(1)
    assert_equal '<a href="/projects/ecookbook/settings">eCookbook</a>', link_to_project_settings(project)

    project.status = Project::STATUS_CLOSED
    assert_equal '<a href="/projects/ecookbook">eCookbook</a>', link_to_project_settings(project)

    project.status = Project::STATUS_ARCHIVED
    assert_equal 'eCookbook', link_to_project_settings(project)
  end

  def test_link_to_legacy_project_with_numerical_identifier_should_use_id
    # numeric identifier are no longer allowed
    Project.where(:id => 1).update_all(:identifier => 25)
    assert_equal '<a href="/projects/1">eCookbook</a>',
                 link_to_project(Project.find(1))
  end

  def test_link_to_record
    [
      [custom_values(:custom_values_007), '<a href="/projects/ecookbook">eCookbook</a>'],
      [documents(:documents_001),         '<a href="/documents/1">Test document</a>'],
      [Group.find(10),                    '<a href="/groups/10">A Team</a>'],
      [issues(:issues_001),               link_to_issue(issues(:issues_001), :subject => false)],
      [messages(:messages_001),           '<a href="/boards/1/topics/1">First post</a>'],
      [news(:news_001),                   '<a href="/news/1">eCookbook first release !</a>'],
      [projects(:projects_001),           '<a href="/projects/ecookbook">eCookbook</a>'],
      [users(:users_001),                 '<a class="user active" href="/users/1">Redmine Admin</a>'],
      [versions(:versions_001),           '<a title="07/01/2006" href="/versions/1">eCookbook - 0.1</a>'],
      [wiki_pages(:wiki_pages_001),       '<a href="/projects/ecookbook/wiki/CookBook_documentation">CookBook documentation</a>']
    ].each do |record, link|
      assert_equal link, link_to_record(record)
    end
  end

  def test_link_to_attachment_container
    field = ProjectCustomField.generate!(:name => "File", :field_format => 'attachment')
    project = projects(:projects_001)
    project_custom_value_attachment = new_record(Attachment) do
      project.custom_field_values = {field.id => {:file => mock_file}}
      project.save
    end

    news_attachment = attachments(:attachments_004)
    news_attachment.container = news(:news_001)
    news_attachment.save!

    [
      [project_custom_value_attachment, '<a href="/projects/ecookbook">eCookbook</a>'],
      [attachments(:attachments_002),   '<a href="/documents/1">Test document</a>'],
      [attachments(:attachments_001),   link_to_issue(issues(:issues_003), :subject => false)],
      [attachments(:attachments_013),   '<a href="/boards/1/topics/1">First post</a>'],
      [news_attachment,                 '<a href="/news/1">eCookbook first release !</a>'],
      [attachments(:attachments_008),   '<a href="/projects/ecookbook/files">Files</a>'],
      [attachments(:attachments_009),   '<a href="/projects/ecookbook/files">Files</a>'],
      [attachments(:attachments_003),   '<a href="/projects/ecookbook/wiki/Page_with_an_inline_image">Page with an inline image</a>'],
    ].each do |attachment, link|
      assert_equal link, link_to_attachment_container(attachment.container)
    end
  end

  def test_principals_options_for_select_with_users
    User.current = nil
    users = [User.find(2), User.find(4)]
    assert_equal(
      %(<option value="2">John Smith</option><option value="4">Robert Hill</option>),
      principals_options_for_select(users))
  end

  def test_principals_options_for_select_with_selected
    User.current = nil
    users = [User.find(2), User.find(4)]
    assert_equal(
      %(<option value="2">John Smith</option><option value="4" selected="selected">Robert Hill</option>),
      principals_options_for_select(users, User.find(4)))
  end

  def test_principals_options_for_select_with_users_and_groups
    User.current = nil
    set_language_if_valid 'en'
    users = [User.find(2), Group.find(11), User.find(4), Group.find(10)]
    assert_equal(
      %(<option value="2">John Smith</option><option value="4">Robert Hill</option>) +
      %(<optgroup label="Groups"><option value="10">A Team</option><option value="11">B Team</option></optgroup>),
      principals_options_for_select(users))
  end

  def test_principals_options_for_select_with_empty_collection
    assert_equal '', principals_options_for_select([])
  end

  def test_principals_options_for_select_should_include_me_option_when_current_user_is_in_collection
    set_language_if_valid 'en'
    users = [User.find(2), User.find(4)]
    User.current = User.find(4)
    assert_include '<option value="4">&lt;&lt; me &gt;&gt;</option>', principals_options_for_select(users)
  end

  def test_stylesheet_link_tag_should_pick_the_default_stylesheet
    assert_match 'href="/stylesheets/styles.css"', stylesheet_link_tag("styles")
  end

  def test_stylesheet_link_tag_for_plugin_should_pick_the_plugin_stylesheet
    assert_match 'href="/plugin_assets/foo/stylesheets/styles.css"', stylesheet_link_tag("styles", :plugin => :foo)
  end

  def test_image_tag_should_pick_the_default_image
    assert_match 'src="/images/image.png"', image_tag("image.png")
  end

  def test_image_tag_should_pick_the_theme_image_if_it_exists
    theme = Redmine::Themes.themes.last
    theme.images << 'image.png'

    with_settings :ui_theme => theme.id do
      assert_match %|src="/themes/#{theme.dir}/images/image.png"|, image_tag("image.png")
      assert_match %|src="/images/other.png"|, image_tag("other.png")
    end
  ensure
    theme.images.delete 'image.png'
  end

  def test_image_tag_sfor_plugin_should_pick_the_plugin_image
    assert_match 'src="/plugin_assets/foo/images/image.png"', image_tag("image.png", :plugin => :foo)
  end

  def test_javascript_include_tag_should_pick_the_default_javascript
    assert_match 'src="/javascripts/scripts.js"', javascript_include_tag("scripts")
  end

  def test_javascript_include_tag_for_plugin_should_pick_the_plugin_javascript
    assert_match 'src="/plugin_assets/foo/javascripts/scripts.js"', javascript_include_tag("scripts", :plugin => :foo)
  end

  def test_raw_json_should_escape_closing_tags
    s = raw_json(["<foo>bar</foo>"])
    assert_include '\/foo', s
  end

  def test_raw_json_should_be_html_safe
    s = raw_json(["foo"])
    assert s.html_safe?
  end

  def test_html_title_should_app_title_if_not_set
    assert_equal 'Redmine', html_title
  end

  def test_html_title_should_join_items
    html_title 'Foo', 'Bar'
    assert_equal 'Foo - Bar - Redmine', html_title
  end

  def test_html_title_should_append_current_project_name
    @project = Project.find(1)
    html_title 'Foo', 'Bar'
    assert_equal 'Foo - Bar - eCookbook - Redmine', html_title
  end

  def test_title_should_return_a_h2_tag
    assert_equal '<h2>Foo</h2>', title('Foo')
  end

  def test_title_should_set_html_title
    title('Foo')
    assert_equal 'Foo - Redmine', html_title
  end

  def test_title_should_turn_arrays_into_links
    assert_equal '<h2><a href="/foo">Foo</a></h2>', title(['Foo', '/foo'])
    assert_equal 'Foo - Redmine', html_title
  end

  def test_title_should_join_items
    assert_equal '<h2>Foo &#187; Bar</h2>', title('Foo', 'Bar')
    assert_equal 'Bar - Foo - Redmine', html_title
  end

  def test_favicon_path
    assert_match %r{^/favicon\.ico}, favicon_path
  end

  def test_favicon_path_with_suburi
    Redmine::Utils.relative_url_root = '/foo'
    assert_match %r{^/foo/favicon\.ico}, favicon_path
  ensure
    Redmine::Utils.relative_url_root = ''
  end

  def test_favicon_url
    assert_match %r{^http://test\.host/favicon\.ico}, favicon_url
  end

  def test_favicon_url_with_suburi
    Redmine::Utils.relative_url_root = '/foo'
    assert_match %r{^http://test\.host/foo/favicon\.ico}, favicon_url
  ensure
    Redmine::Utils.relative_url_root = ''
  end

  def test_truncate_single_line
    str = "01234"
    result = truncate_single_line_raw("#{str}\n#{str}", 10)
    assert_equal "01234 0...", result
    assert !result.html_safe?
    result = truncate_single_line_raw("#{str}<&#>\n#{str}#{str}", 16)
    assert_equal "01234<&#> 012...", result
    assert !result.html_safe?
  end

  def test_truncate_single_line_non_ascii
    ja = '日本語'
    result = truncate_single_line_raw("#{ja}\n#{ja}\n#{ja}", 10)
    assert_equal "#{ja} #{ja}...", result
    assert !result.html_safe?
  end

  def test_hours_formatting
    set_language_if_valid 'en'

    with_settings :timespan_format => 'minutes' do
      assert_equal '0:45', format_hours(0.75)
      assert_equal '0:45 h', l_hours_short(0.75)
      assert_equal '0:45 hour', l_hours(0.75)
    end
    with_settings :timespan_format => 'decimal' do
      assert_equal '0.75', format_hours(0.75)
      assert_equal '0.75 h', l_hours_short(0.75)
      assert_equal '0.75 hour', l_hours(0.75)
    end
  end

  def test_html_hours
    assert_equal '<span class="hours hours-int">0</span><span class="hours hours-dec">:45</span>', html_hours('0:45')
    assert_equal '<span class="hours hours-int">0</span><span class="hours hours-dec">.75</span>', html_hours('0.75')
  end

  def test_form_for_includes_name_attribute
    assert_match(/name="new_issue-[a-z0-9]{8}"/, form_for(Issue.new){})
  end

  def test_labelled_form_for_includes_name_attribute
    assert_match(/name="new_issue-[a-z0-9]{8}"/, labelled_form_for(Issue.new){})
  end


  private

  def wiki_links_with_special_characters
    return {
      '[[Jack & Coke]]' =>
          link_to("Jack & Coke",
                  "/projects/ecookbook/wiki/Jack_&_Coke",
                  :class => "wiki-page new"),
      '[[a "quoted" name]]' =>
          link_to("a \"quoted\" name",
                  "/projects/ecookbook/wiki/A_%22quoted%22_name",
                  :class => "wiki-page new"),
      '[[le français, c\'est super]]' =>
          link_to("le français, c\'est super",
                  "/projects/ecookbook/wiki/Le_fran%C3%A7ais_c'est_super",
                  :class => "wiki-page new"),
      '[[broken < less]]' =>
          link_to("broken < less",
                  "/projects/ecookbook/wiki/Broken_%3C_less",
                  :class => "wiki-page new"),
      '[[broken > more]]' =>
          link_to("broken > more",
                  "/projects/ecookbook/wiki/Broken_%3E_more",
                  :class => "wiki-page new"),
      '[[[foo]Including [square brackets] in wiki title]]' =>
          link_to("[foo]Including [square brackets] in wiki title",
                  "/projects/ecookbook/wiki/%5Bfoo%5DIncluding_%5Bsquare_brackets%5D_in_wiki_title",
                  :class => "wiki-page new"),
    }
  end

  def test_export_csv_encoding_select_tag_should_return_nil_when_general_csv_encoding_is_UTF8
    with_locale 'az' do
      assert_equal l(:general_csv_encoding), 'UTF-8'
      assert_nil export_csv_encoding_select_tag
    end
  end

  def test_export_csv_encoding_select_tag_should_have_two_option_when_general_csv_encoding_is_not_UTF8
    with_locale 'en' do
      assert_not_equal l(:general_csv_encoding), 'UTF-8'
      result = export_csv_encoding_select_tag
      assert_select_in result, "option[selected='selected'][value=#{l(:general_csv_encoding)}]", :text => l(:general_csv_encoding)
      assert_select_in result, "option[value='UTF-8']", :text => 'UTF-8'
    end
  end
end
