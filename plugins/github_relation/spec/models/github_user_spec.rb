require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe 'github_user' do
  let!(:project){Project.create(name: 'github_test', identifier: 'github_test')}

  context "create_users" do

    before do
      github_users =
          10.times.map do |index|
            user = Hashie::Mash.new
            user.login = "login#{index}"
            user
          end
      GithubUser.create_users(github_users)
    end

    subject{GithubUser.scoped.order(:login)}
    its(:count){should == 10}
    it "GithubUsers" do
      subject.each_with_index do |github_user, index|
        github_user.login.should == "login#{index}"
      end
    end
  end
end