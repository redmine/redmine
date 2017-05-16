require File.dirname(__FILE__) + '/../test_helper'

require 'mocha'

class BitbucketHookControllerTest < ActionController::TestCase

  def setup
    # Sample JSON post from http://confluence.atlassian.com/display/BBDEV/Writing+Brokers+for+Bitbucket#the-payload
    @json = <<-EOF
{"broker": "twitter",
 "commits": [{ "author": "jespern",
               "files": [{"file": "media/css/layout.css",
                           "type": "modified"},
                          {"file": "apps/bb/views.py",
                           "type": "modified"},
                          {"file": "templates/issues/issue.html",
                           "type": "modified"}],
               "message": "adding bump button, issue #206 fixed",
               "node": "e71c63bcc05e",
               "revision": 1650,
               "size": 684}],
 "repository": { "absolute_url": "/jespern/bitbucket/",
                 "name": "bitbucket",
                 "owner": "jespern",
                 "slug": "bitbucket",
                 "website": "http://bitbucket.org/"},
 "service": {"password": "bar", "username": "foo"}}
EOF
    @repository = Repository::Mercurial.new
    @repository.stubs(:fetch_changesets).returns(true)

    @project = Project.new
    @project.stubs(:repository).returns(@repository)
    Project.stubs(:find_by_identifier).with('bitbucket').returns(@project)
    @controller = BitbucketHookController.new
    @controller.stubs(:exec)

    Repository.expects(:fetch_changesets).never
  end

  def do_post(payload = nil)
    payload = @json if payload.nil?
    payload = payload.to_json if payload.is_a?(Hash)
    post :index, :payload => payload
  end

  def test_should_use_the_repository_name_as_project_identifier
    Project.expects(:find_by_identifier).with('bitbucket').returns(@project)
    do_post
  end

  def test_should_update_the_repository_using_hg_on_the_commandline
    Project.expects(:find_by_identifier).with('bitbucket').returns(@project)
    @controller.expects(:exec).returns(true)
    do_post
  end

  def test_should_render_ok_when_done
    do_post
    assert_response :success
    assert_equal 'OK', @response.body
  end

  def test_should_fetch_changesets_into_the_repository
    @repository.expects(:fetch_changesets).returns(true)
    do_post
    assert_response :success
    assert_equal 'OK', @response.body
  end

  def test_should_return_404_if_project_not_found
    assert_raises ActiveRecord::RecordNotFound do
      Project.expects(:find_by_identifier).with('foobar').returns(nil)
      do_post :repository => {:name => 'foobar'}
    end
  end

  def test_should_return_500_if_project_has_no_repository
    assert_raises TypeError do
      project = mock('project')
      project.expects(:repository).returns(nil)
      Project.expects(:find_by_identifier).with('bitbucket').returns(project)
      do_post :repository => {:name => 'bitbucket'}
    end
  end

  def test_should_return_500_if_repository_is_not_mercurial
    assert_raises TypeError do
      project = mock('project')
      repository = Repository::Subversion.new
      project.expects(:repository).at_least(1).returns(repository)
      Project.expects(:find_by_identifier).with('bitbucket').returns(project)
      do_post :repository => {:name => 'bitbucket'}
    end
  end

  def test_should_not_require_login
    @controller.expects(:check_if_login_required).never
    do_post
  end

end
