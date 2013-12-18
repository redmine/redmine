class GithubIssue < ActiveRecord::Base
  attr_accessible :issue_number

  belongs_to :issue

  def self.create_issues(project, list_issues)
    Issue.skip_callback(:save, :before, :force_updated_on_change)

    list_issues.each do |issue_from_github|
      github_issue = GithubIssue.where(issue_number: issue_from_github.number).first_or_create()
      issue = github_issue.issue || github_issue.build_issue

      next if issue.updated_on.present? && issue.updated_on > issue_from_github.updated_at

      author = if GithubUser.exists?(login:issue_from_github.user.login)
                  GithubUser.where(login:issue_from_github.user.login).first.user
               else
                 User.first
               end

      issue.subject = issue_from_github.title
      issue.description = issue_from_github.body
      issue.project = project
      issue.tracker = Tracker.first
      issue.author = author
      issue.assigned_to = GithubUser.where(login:issue_from_github.assignee.login).first.user if issue_from_github.assignee.present?
      issue.created_on = issue_from_github.created_at
      issue.updated_on = issue_from_github.updated_at
      issue.save!
      github_issue.save!
    end

    Issue.set_callback(:save, :before, :force_updated_on_change)
  end
end
