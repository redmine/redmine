class GithubUser < ActiveRecord::Base
  attr_accessible :login

  belongs_to :user

  def self.create_users(users)
    users.each do |user_from_github|
      next if GithubUser.exists?(login: user_from_github.login)

      github_user = GithubUser.new(login: user_from_github.login)
      user = github_user.build_user
      user.login = github_user.login
      user.firstname = github_user.login
      user.lastname = github_user.login
      user.mail = "#{github_user.login}@piyo.hoge"
      user.save!
      github_user.save!
    end
  end

  def self.user_by_github_login(github_user, default = nil)
    return default unless self.exists?(login: github_user.login)
    self.where(login: github_user.login).first.user
  end
end
