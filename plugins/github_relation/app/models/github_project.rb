class GithubProject < ActiveRecord::Base
  attr_accessible :organization, :project_name

  belongs_to :project

  def get_from_github(login, password)
    github_relation = Github::Relation.new(login, password)

    GithubUser.create_users(github_relation.users(self.organization))
    GithubIssue.create_issues(self.project, github_relation.issues(self.organization, self.project_name))
  end
end
