class AddHostNameToProjectEmails < ActiveRecord::Migration[6.1]
  def self.up
    # add_column :project_emails, :host_name, :string
  end

  def self.down
    # remove_column :project_emails, :host_name
  end
end
