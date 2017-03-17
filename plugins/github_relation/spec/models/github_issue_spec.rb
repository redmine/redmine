require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe 'github_issue' do
  fixtures :trackers, :issue_statuses, :enumerations, :users

  let!(:project){Project.create(name: 'github_test', identifier: 'github_test')}

  context "create_issues" do

    before do
      github_users = %w{user assignee}.map do |user_name|
                        user = Hashie::Mash.new
                        user.login = "#{user_name}_login"
                        user
                      end
      GithubUser.create_users(github_users)

      github_issues = 10.times.map do |index|
                        issue = Hashie::Mash.new
                        issue.number = index
                        issue.title = "title#{index}"
                        issue.body = "body#{index}"
                        issue.created_at = Time.parse("2010/01/01")
                        issue.updated_at = Time.parse("2011/01/01")
                        issue.user = github_users[0]
                        issue
                      end
      github_issues[5].assignee = github_users[1]
      github_issues[6].user.login = "hoge"

      GithubIssue.create_issues(project, github_issues)
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
      end
    end
    it "GithubIssues User" do
      user = GithubUser.where(login: "user_login").first.user

      (0..4).each do |index|
        subject[index].issue.author.should == user
        subject[index].issue.assigned_to.should == nil
      end
      (7..9).each do |index|
        subject[index].issue.author.should == user
        subject[index].issue.assigned_to.should == nil
      end

      subject[5].issue.author.should == user
      subject[5].issue.assigned_to.should == GithubUser.where(login: "assignee_login").first.user
      subject[6].issue.author.should == User.first
      subject[6].issue.assigned_to.should == nil
    end
  end
end