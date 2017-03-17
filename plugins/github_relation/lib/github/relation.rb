module Github
  class Relation

    def initialize(login, password)
      @login = login
      @password = password
    end

    def client
      @client || Octokit::Client.new(login: @login, password: @password)
    end

    def issues(organization, project)
      target = "#{organization}/#{project}"
      list_issues_all = []
      page = 1
      list_issues = client.list_issues(target, page: page, per_page: 100)
      while list_issues != []
        list_issues_all += list_issues
        page += 1
        list_issues = client.list_issues(target, page: page, per_page: 100)
      end
      list_issues_all
    end

    def users(organization)
      client.organization_members(organization)
    end

  end
end