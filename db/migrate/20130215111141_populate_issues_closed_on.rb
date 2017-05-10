class PopulateIssuesClosedOn < ActiveRecord::Migration
  def up
    closed_status_ids = IssueStatus.where(:is_closed => true).pluck(:id)
    if closed_status_ids.any?
      # First set closed_on for issues that have been closed once
      closed_status_values = closed_status_ids.map {|status_id| "'#{status_id}'"}.join(',')
      subselect = "SELECT MAX(#{Journal.table_name}.created_on)" +
        " FROM #{Journal.table_name}, #{JournalDetail.table_name}" +
        " WHERE #{Journal.table_name}.id = #{JournalDetail.table_name}.journal_id" +
        " AND #{Journal.table_name}.journalized_type = 'Issue' AND #{Journal.table_name}.journalized_id = #{Issue.table_name}.id" +
        " AND #{JournalDetail.table_name}.property = 'attr' AND #{JournalDetail.table_name}.prop_key = 'status_id'" +
        " AND #{JournalDetail.table_name}.old_value NOT IN (#{closed_status_values})" +
        " AND #{JournalDetail.table_name}.value IN (#{closed_status_values})"
      Issue.update_all "closed_on = (#{subselect})"

      # Then set closed_on for closed issues that weren't up updated by the above UPDATE
      # No journal was found so we assume that they were closed on creation
      Issue.where({:status_id => closed_status_ids, :closed_on => nil}).
               update_all("closed_on = created_on")
    end
  end

  def down
    Issue.update_all :closed_on => nil
  end
end
