module ReportsControllerPatch
  def self.included(base)
    base.class_eval do
      # Insert overrides here, for example:
      def issue_report
        # authorize if user has at least one role that has this permission
        current_user = User.current
        roles = current_user.memberships.collect {|m| m.roles}.flatten.uniq
        roles << (current_user.logged? ? Role.non_member : Role.anonymous)
        raise Unauthorized unless (roles.any? {|role| role.allowed_to?(:view_project_reports,)} || current_user.admin?)


        @trackers = @project.rolled_up_trackers(false).visible
        @versions = @project.shared_versions.sort
        @priorities = IssuePriority.all.reverse
        @categories = @project.issue_categories
        @assignees = (Setting.issue_group_assignment? ? @project.principals : @project.users).sort
        @authors = @project.users.sort
        @subprojects = @project.descendants.visible

        @issues_by_tracker = Issue.by_tracker(@project)
        @issues_by_version = Issue.by_version(@project)
        @issues_by_priority = Issue.by_priority(@project)
        @issues_by_category = Issue.by_category(@project)
        @issues_by_assigned_to = Issue.by_assigned_to(@project)
        @issues_by_author = Issue.by_author(@project)
        @issues_by_subproject = Issue.by_subproject(@project) || []

        render :template => "reports/issue_report"
        { :controller => params[:controller], :action => params[:action] }
      end
    end
  end
end
