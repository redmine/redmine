class PopulateEnumerationsPositionName < ActiveRecord::Migration[4.2]
  def up
    IssuePriority.compute_position_names
  end

  def down
    IssuePriority.clear_position_names
  end
end
