class ClearEstimatedHoursOnParentIssues < ActiveRecord::Migration[4.2]
  def self.up
    # Clears estimated hours on parent issues
    Issue.where("rgt > lft + 1 AND estimated_hours > 0").update_all :estimated_hours => nil
  end

  def self.down
    table_name = Issue.table_name
    leaves_sum_select = "SELECT SUM(leaves.estimated_hours) FROM (SELECT * FROM #{table_name}) AS leaves" +
      " WHERE leaves.root_id = #{table_name}.root_id AND leaves.lft > #{table_name}.lft AND leaves.rgt < #{table_name}.rgt" +
      " AND leaves.rgt = leaves.lft + 1"

    Issue.where("rgt > lft + 1").update_all "estimated_hours = (#{leaves_sum_select})"
  end
end
