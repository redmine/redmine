class ChangeSqliteBooleansDefault < ActiveRecord::Migration[5.2]
  DEFAULTS = {
    "auth_sources" => {
      "onthefly_register" => false,
      "tls" => false
    },
    "custom_field_enumerations" => {
      "active" => true
    },
    "custom_fields" => {
      "is_required" => false,
      "is_for_all" => false,
      "is_filter" => false,
      "searchable" => false,
      "editable" => true,
      "visible" => true,
      "multiple" => false
    },
    "email_addresses" => {
      "is_default" => false,
      "notify" => true
    },
    "enumerations" => {
      "is_default" => false,
      "active" => true
    },
    "imports" => {
      "finished" => false
    },
    "issue_statuses" => {
      "is_closed" => false
    },
    "issues" => {
      "is_private" => false
    },
    "journals" => {
      "private_notes" => false
    },
    "members" => {
      "mail_notification" => false
    },
    "messages" => {
      "locked" => false
    },
    "projects" => {
      "is_public" => true,
      "inherit_members" => false
    },
    "repositories" => {
      "is_default" => false
    },
    "roles" => {
      "assignable" => true,
      "all_roles_managed" => true
    },
    "trackers" => {
      "is_in_chlog" => false,
      "is_in_roadmap" => true
    },
    "user_preferences" => {
      "hide_mail" => true
    },
    "users" => {
      "admin" => false,
      "must_change_passwd" => false
    },
    "wiki_pages" => {
      "protected" => false
    },
    "workflows" => {
      "assignee" => false,
      "author" => false
    }
  }

  def up
    if ActiveRecord::Base.connection.adapter_name =~ /sqlite/i
      DEFAULTS.each do |table, defaults|
        defaults.each do |column, value|
          # Reset default values for boolean column (t/f => 1/0)
          change_column_default(table, column, value)
        end
      end
    end
  end

  def down
    if ActiveRecord::Base.connection.adapter_name =~ /sqlite/i
      # Cannot restore default values as t/f
      raise ActiveRecord::IrreversibleMigration
    end
  end
end
