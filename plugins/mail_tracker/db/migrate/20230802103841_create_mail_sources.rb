class CreateMailSources < ActiveRecord::Migration[6.1]
  def change
    # create_table :mail_sources do |t|
    #   t.integer :default_project_id
    #   t.integer :default_user_id
    #   t.string :username
    #   t.string :password
    #   t.string :host
    #   t.integer :delivery_port
    #   t.string :receive_host
    #   t.integer :receive_port
    #   t.string :receive_protocol
    #   t.boolean :use_ssl, default: true
    #   t.boolean :use_tls, default: false
    #   t.string :email_address
    #   t.integer :no_rules_project_id
    #   t.text :reply_cut_from
    #   t.boolean :enabled_sync, default: false
    #   t.boolean :oauth_enabled, default: false
    #   t.string :application_id
    #   t.string :azure_code
    #   t.string :id_token
    #   t.string :access_token
    #   t.string :refresh_token

    #   t.json :projects_to_sync

    #   t.timestamps
    # end

    # create_table :mail_tracking_rules do |t|
    #   t.string :mail_part
    #   t.string :includes
    #   t.integer :assigned_group_id
    #   t.integer :assigned_project_id
    #   t.string :tracker_name
    #   t.string :login_name
    #   t.string :priority
    #   t.integer :end_duration
    #   t.timestamps
    # end

    # create_join_table :mail_tracking_rules, :issues do |t|
    #   t.index :mail_tracking_rule_id
    #   t.index :issue_id
    # end

    # create_table :email_templates do |t|
    #   t.string :domain
    #   t.text :body
    # end
    # EmailTemplate.create({ domain: 'Default', body: File.read(File.expand_path('./data/default_email_template.txt', __dir__)) })

    # add_column :issues, :message_id, :string, default: nil
    # add_column :issues, :reply_message_id, :string, default: nil

    # add_column :attachments, :mail_content_id, :string

    # add_column :projects, :warrant_pricing, :string, default: nil
    # add_column :projects, :non_warrant_pricing, :string, default: nil
    # add_column :projects, :warrant_start, :datetime, default: nil
    # add_column :projects, :warrant_month, :integer, default: nil
    # add_column :projects, :sla_1_enabled, :boolean, default: false
    # add_column :projects, :sla_2_enabled, :boolean, default: false
    # add_column :projects, :sla_1_start, :datetime, default: nil
    # add_column :projects, :sla_2_start, :datetime, default: nil
    # add_column :projects, :sla_1_month, :integer, default: nil
    # add_column :projects, :sla_2_month, :integer, default: nil
    # add_column :projects, :cloud_enabled, :boolean, default: false
    # add_column :projects, :rent_enabled, :boolean, default: false
    # add_column :projects, :cloud_start, :datetime, default: nil
    # add_column :projects, :rent_start, :datetime, default: nil
    # add_column :projects, :cloud_month, :integer, default: nil
    # add_column :projects, :rent_month, :integer, default: nil
    # add_column :projects, :warrant_comment, :text
    # add_column :projects, :warranty_comment, :text
    # add_column :projects, :sla_1_comment, :text
    # add_column :projects, :sla_2_comment, :text
    # add_column :projects, :cloud_comment, :text
    # add_column :projects, :rent_comment, :text

    # add_column :users, :group_email, :string, default: nil
  end
end
