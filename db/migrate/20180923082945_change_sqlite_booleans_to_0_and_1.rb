class ChangeSqliteBooleansTo0And1 < ActiveRecord::Migration[5.2]

  COLUMNS = {
    AuthSource => ['onthefly_register', 'tls'],
    CustomFieldEnumeration => ['active'],
    CustomField => ['is_required', 'is_for_all', 'is_filter', 'searchable', 'editable', 'visible', 'multiple'],
    EmailAddress => ['is_default', 'notify'],
    Enumeration => ['is_default', 'active'],
    Import => ['finished'],
    IssueStatus => ['is_closed'],
    Issue => ['is_private'],
    Journal => ['private_notes'],
    Member => ['mail_notification'],
    Message => ['locked'],
    Project => ['is_public', 'inherit_members'],
    Repository => ['is_default'],
    Role => ['assignable', 'all_roles_managed'],
    Tracker => ['is_in_chlog', 'is_in_roadmap'],
    UserPreference => ['hide_mail'],
    User => ['admin', 'must_change_passwd'],
    WikiPage => ['protected'],
    WorkflowRule => ['assignee', 'author'],
  }

  def up
    if /sqlite/i.match?(ActiveRecord::Base.connection.adapter_name)
      COLUMNS.each do |klass, columns|
        columns.each do |column|
          klass.where("#{column} = 't'").update_all(column => 1)
          klass.where("#{column} = 'f'").update_all(column => 0)
        end
      end
    end
  end

  def down
    if /sqlite/i.match?(ActiveRecord::Base.connection.adapter_name)
      COLUMNS.each do |klass, columns|
        columns.each do |column|
          klass.where("#{column} = 1").update_all(column => 't')
          klass.where("#{column} = 0").update_all(column => 'f')
        end
      end
    end
  end
end
