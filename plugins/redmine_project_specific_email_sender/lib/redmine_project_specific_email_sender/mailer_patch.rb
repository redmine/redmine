module RedmineProjectSpecificEmailSender
  module MailerPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
      # base.class_eval do
      #   alias_method_chain :mail, :project_specific_email
      #   alias_method_chain :issue_add, :project_specific_email
      #   alias_method_chain :issue_edit, :project_specific_email
      #   alias_method_chain :document_added, :project_specific_email
      #   alias_method_chain :attachments_added, :project_specific_email
      #   alias_method_chain :news_added, :project_specific_email
      #   alias_method_chain :message_posted, :project_specific_email
      #   alias_method_chain :wiki_content_added, :project_specific_email
      #   alias_method_chain :wiki_content_updated, :project_specific_email
      # end
    end

    module InstanceMethods
      def mail_with_project_specific_email(headers={})
        if (@project)
          headers['X-Redmine-Project-Specific-Sender'] = @project.email
        end
        @issue_url = @issue_url_by_project if @issue_url_by_project
        mail_without_project_specific_email(headers)
      end

      def issue_add_with_project_specific_email(*args)
        @project = args.first.project
        @issue_url_by_project = url_for(:controller => 'issues', :action => 'show', :id => args.first, :host => @project.crm_host_name)
        issue_add_without_project_specific_email(*args)
      end

      def issue_edit_with_project_specific_email(*args)
        @project = args.first.journalized.project
        @issue_url_by_project = url_for(:controller => 'issues', :action => 'show', :id => args.first.journalized, :anchor => "change-#{args.first.id}", :host => @project.crm_host_name)
        issue_edit_without_project_specific_email(*args)
      end

      def document_added_with_project_specific_email(*args)
        @project = args.first.project
        document_added_without_project_specific_email(*args)
      end

      def attachments_added_with_project_specific_email(*args)
        @project = args.first.first.container.project
        attachments_added_without_project_specific_email(*args)
      end

      def news_added_with_project_specific_email(*args)
        @project = args.first.project
        news_added_without_project_specific_email(*args)
      end

      def message_posted_with_project_specific_email(*args)
        @project = args.first.board.project
        message_posted_without_project_specific_email(*args)
      end

      def wiki_content_added_with_project_specific_email(*args)
        @project = args.first.project
        wiki_content_added_without_project_specific_email(*args)
      end

      def wiki_content_updated_with_project_specific_email(*args)
        @project = args.first.project
        wiki_content_updated_without_project_specific_email(*args)
      end
    end
  end
end
