require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe 'github_user' do
  let!(:project){Project.create(name: 'github_test', identifier: 'github_test')}

  describe "create_users" do
    before do
      github_users =
          10.times.map do |index|
            user = Hashie::Mash.new
            user.login = "login#{index}"
            user
          end
      GithubUser.create_users(github_users)
    end

    context "create" do
      subject{GithubUser.scoped.order(:login)}
      its(:count){should == 10}
      it "GithubUsers" do
        subject.each_with_index do |github_user, index|
          github_user.login.should == "login#{index}"
        end
      end
    end

    context "duplicate" do
      before do
        user = Hashie::Mash.new
        user.login = "login6"
        GithubUser.create_users([user])
      end

      subject{GithubUser.scoped.order(:login)}
      its(:count){should == 10}
      it "GithubUsers" do
        subject.each_with_index do |github_user, index|
          github_user.login.should == "login#{index}"
        end
      end
    end

    context "add" do
      before do
        user = Hashie::Mash.new
        user.login = "login10"
        GithubUser.create_users([user])
      end

      subject{GithubUser.scoped.order(:login)}
      its(:count){should == 11}
      it "GithubUsers" do
        login_idx = [0,1,10,2,3,4,5,6,7,8,9]

        subject.each_with_index do |github_user, index|
          github_user.login.should == "login#{login_idx[index]}"
        end
      end
    end
  end
end