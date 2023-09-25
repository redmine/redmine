module RedmineProjectSpecificEmailSender
  module ProjectPatch

    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        has_one :project_email
        has_many :project_watchers, dependent: :destroy
        has_many :watcher_groups, through: :project_watchers, source: :group
      end
    end

    module InstanceMethods
      def host_name
        if project_email && project_email.host_name.present?
          project_email.host_name
        else
          parent_project_setting('host_name')
        end
      end

      def crm_host_name
        host_name['crm.'] ? host_name : "crm.#{host_name}"
      end

      def host_name=(host)
        project_email ? (project_email.host_name = host) : build_project_email(:host_name => host)
      end

      def email
        if project_email && project_email.email.present?
          project_email.email
        else
          parent_project_setting('email')
        end
      end

      def email=(email_address)
        project_email ? (project_email.email = email_address) : build_project_email(:email => email_address)
      end

      def emails_info
        if project_email && project_email.emails_info.present?
          project_email.emails_info
        else
          parent_project_setting('emails_info')
        end
      end

      def emails_info=(info)
        project_email ? (project_email.emails_info = info) : build_project_email(emails_info: info)
      end

      def emails_header
        if project_email && project_email.emails_header.present?
          project_email.emails_header
        else
          parent_project_setting('emails_header')
        end
      end

      def emails_header=(header)
        project_email ? (project_email.emails_header = header) : build_project_email(emails_header: header)
      end

      def emails_footer
        if project_email && project_email.emails_footer.present?
          project_email.emails_footer
        else
          parent_project_setting('emails_footer')
        end
      end

      def emails_footer=(footer)
        project_email ? (project_email.emails_footer = footer) : build_project_email(emails_footer: footer)
      end

      private

      def parent_project_setting(setting)
        if parent
          parent.send(setting.to_sym)
        else
          setting == 'email' ? Setting.send(:mail_from) : Setting.send(setting.to_sym)
        end
      end
    end

  end
end
