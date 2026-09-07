class DeleteOrphanedWorkflowRulesOfCustomFields < ActiveRecord::Migration[8.1]
  def up
    field_names = WorkflowPermission.where.not(field_name: nil).distinct.pluck(:field_name)
    custom_field_ids = field_names.grep(/\A\d+\z/).map(&:to_i)
    orphaned_ids = custom_field_ids - CustomField.where(id: custom_field_ids).pluck(:id)
    if orphaned_ids.any?
      WorkflowPermission.where(field_name: orphaned_ids.map(&:to_s)).delete_all
    end
  end

  def down
    # no-op
  end
end
