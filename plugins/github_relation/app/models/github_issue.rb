class GithubIssue < ActiveRecord::Base
  attr_accessible :issue_number

  belongs_to :issue

  def self.create_issues(project, list_issues)
    Issue.skip_callback(:save, :before, :force_updated_on_change)

    list_issues.each do |issue_from_github|
      github_issue = GithubIssue.where(issue_number: issue_from_github.number).first_or_create()
      github_issue.create_issue_from_github(project, issue_from_github)
      github_issue.save!
    end

    Issue.set_callback(:save, :before, :force_updated_on_change)
  end

  def create_issue_from_github(project, issue_from_github)
    self.build_issue if issue.nil?
    return if issue.updated_on.present? && issue.updated_on > issue_from_github.updated_at

    issue.subject = issue_from_github.title
    issue.description = issue_from_github.body
    issue.project = project
    issue.tracker = Tracker.first
    issue.author = GithubUser.user_by_github_login(issue_from_github.user, User.first)
    if issue_from_github.assignee.present?
      issue.assigned_to = GithubUser.user_by_github_login(issue_from_github.assignee)
    end
    issue.created_on = issue_from_github.created_at
    issue.updated_on = issue_from_github.updated_at
    issue.save!
  end
end
