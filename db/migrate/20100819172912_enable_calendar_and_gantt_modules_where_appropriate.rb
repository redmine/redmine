class EnableCalendarAndGanttModulesWhereAppropriate < ActiveRecord::Migration[4.2]
  def self.up
    EnabledModule.where(:name => 'issue_tracking').each do |e|
      EnabledModule.create(:name => 'calendar', :project_id => e.project_id)
      EnabledModule.create(:name => 'gantt', :project_id => e.project_id)
    end
  end

  def self.down
    EnabledModule.where("name = 'calendar' OR name = 'gantt'").delete_all
  end
end
