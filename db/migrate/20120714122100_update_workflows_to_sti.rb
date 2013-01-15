class UpdateWorkflowsToSti < ActiveRecord::Migration
  def up
    WorkflowRule.update_all "type = 'WorkflowTransition'"
  end

  def down
    WorkflowRule.update_all "type = NULL"
  end
end
