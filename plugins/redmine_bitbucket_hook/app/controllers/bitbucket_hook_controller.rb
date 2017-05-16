require 'json'

class BitbucketHookController < ApplicationController

  skip_before_filter :verify_authenticity_token, :check_if_login_required

  def index
    payload = JSON.parse(params[:payload])
    logger.debug { "Received from Bitbucket: #{payload.inspect}" }

    # For now, we assume that the repository name is the same as the project identifier
    identifier = payload['repository']['name']

    project = Project.find_by_identifier(identifier)
    raise ActiveRecord::RecordNotFound, "No project found with identifier '#{identifier}'" if project.nil?

    repository = project.repository
    raise TypeError, "Project '#{identifier}' has no repository" if repository.nil?
    raise TypeError, "Repository for project '#{identifier}' is not a BitBucket repository" unless repository.is_a?(Repository::Mercurial) || repository.is_a?(Repository::Git)

    # Get updates from the bitbucket repository
    if repository.is_a?(Repository::Git)
      update_git_repository(repository)
    else
      command = "hg --repository \"#{repository.url}\" pull"
      exec(command)
    end

    # Fetch the new changesets into Redmine
    repository.fetch_changesets

    render(:text => 'OK')
  end

  private

  def exec(command)
    logger.info { "BitbucketHook: Executing command: '#{command}'" }
    output = Kernel.system("#{command}")
    logger.info { "BitbucketHook: Shell returned '#{output}'" }
  end

  # Taken from: https://github.com/koppen/redmine_github_hook
  def git_command(command, repository)
    "git --git-dir='#{repository.url}' #{command}"
  end

  def update_git_repository(repository)
    command = git_command('fetch origin', repository)
    if exec(command)
      command = git_command("fetch origin '+refs/heads/*:refs/heads/*'", repository)
      exec(command)
    end
  end

end
