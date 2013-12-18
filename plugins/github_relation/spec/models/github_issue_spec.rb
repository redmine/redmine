require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe 'github_issue' do
  fixtures :trackers, :issue_statuses, :enumerations, :users

  let!(:project){Project.create(name: 'github_test', identifier: 'github_test')}

  context "create_issues" do

    before do
      user = Hashie::Mash.new
      user.login = "user_login"
      assignee = Hashie::Mash.new
      assignee.login = "assignee_login"

      @github_issues = 10.times.map do |index|
                        issue = Hashie::Mash.new
                        issue.number = index
                        issue.title = "title#{index}"
                        issue.body = "body#{index}"
                        issue.created_at = Time.parse("2010/01/01")
                        issue.updated_at = Time.parse("2011/01/01")
                        issue.user = user
                        issue
                      end
      @github_issues[5].assignee = assignee
      GithubIssue.create_issues(project, @github_issues)
    end

    subject{GithubIssue.scoped.order(:issue_number)}
    its(:count){should == 10}
    it "GithubIssues" do
      subject.each_with_index do |github_issue, index|
        github_issue.issue_number.should == index
        github_issue.issue.subject.should == "title#{index}"
        github_issue.issue.description.should == "body#{index}"
        github_issue.issue.created_on.should == Time.parse("2010/01/01")
        github_issue.issue.updated_on.should == Time.parse("2011/01/01")
        github_issue.issue.author.should == User.first
        github_issue.issue.assigned_to.should == nil
      end
    end
  end
end