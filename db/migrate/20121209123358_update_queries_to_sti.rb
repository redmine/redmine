class UpdateQueriesToSti < ActiveRecord::Migration
  def up
    ::Query.update_all :type => 'IssueQuery'
  end

  def down
    ::Query.update_all :type => nil
  end
end
