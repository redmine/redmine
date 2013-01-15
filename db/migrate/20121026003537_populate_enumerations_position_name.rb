class PopulateEnumerationsPositionName < ActiveRecord::Migration
  def up
    IssuePriority.compute_position_names
  end

  def down
    IssuePriority.clear_position_names
  end
end
