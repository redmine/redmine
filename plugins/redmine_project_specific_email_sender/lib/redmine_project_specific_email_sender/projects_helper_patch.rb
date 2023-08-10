module RedmineProjectSpecificEmailSender
  module ProjectsHelperPatch

    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        alias_method_chain :project_settings_tabs, :outbound_email_tab
      end
    end

    module InstanceMethods
      def project_settings_tabs_with_outbound_email_tab
        # Grab standard set of tabs
        tabs = project_settings_tabs_without_outbound_email_tab
        tabs.push({ :name => 'outbound_email',
                      :action => :edit_project_email,
                      :partial => 'project_emails/edit',
                      :label => :project_email_label})
        tabs.select {|tab| User.current.allowed_to?(tab[:action], @project)}
      end
    end

  end
end
