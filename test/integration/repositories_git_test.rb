require File.expand_path('../../test_helper', __FILE__)

class RepositoriesGitTest < ActionController::IntegrationTest
  fixtures :projects, :users, :roles, :members, :member_roles,
           :repositories, :enabled_modules

  REPOSITORY_PATH = Rails.root.join('tmp/test/git_repository').to_s
  REPOSITORY_PATH.gsub!(/\//, "\\") if Redmine::Platform.mswin?
  PRJ_ID     = 3

  def setup
    User.current = nil
    @project    = Project.find(PRJ_ID)
    @repository = Repository::Git.create(
                      :project       => @project,
                      :url           => REPOSITORY_PATH,
                      :path_encoding => 'ISO-8859-1'
                      )
    assert @repository
  end

  if File.directory?(REPOSITORY_PATH)
    def test_index
      get '/projects/subproject1/repository/'
      assert_response :success
    end

    def test_diff_two_revs
      get '/projects/subproject1/repository/diff?rev=61b685fbe&rev_to=2f9c0091'
      assert_response :success
    end
  end
end
