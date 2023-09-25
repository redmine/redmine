class AddEmailsInfoHeaderFooterToProjectEmails < ActiveRecord::Migration[6.1]
  def self.up
    # add_column :project_emails, :emails_info, :text
    # add_column :project_emails, :emails_header, :text
    # add_column :project_emails, :emails_footer, :text
  end

  def self.down
    # remove_column :project_emails, :emails_info
    # remove_column :project_emails, :emails_header
    # remove_column :project_emails, :emails_footer
  end
end
