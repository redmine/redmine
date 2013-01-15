class AddWorkflowsAssigneeAndAuthor < ActiveRecord::Migration
  def self.up
    add_column :workflows, :assignee, :boolean, :null => false, :default => false
    add_column :workflows, :author, :boolean, :null => false, :default => false

    WorkflowRule.update_all(:assignee => false)
    WorkflowRule.update_all(:author => false)
  end

  def self.down
    remove_column :workflows, :assignee
    remove_column :workflows, :author
  end
end
