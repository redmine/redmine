class SupportForMultipleCommitKeywords < ActiveRecord::Migration[4.2]
  def up
    # Replaces commit_fix_keywords, commit_fix_status_id, commit_fix_done_ratio settings
    # with commit_update_keywords setting
    keywords = Setting.where(:name => 'commit_fix_keywords').pick(:value)
    status_id = Setting.where(:name => 'commit_fix_status_id').pick(:value)
    done_ratio = Setting.where(:name => 'commit_fix_done_ratio').pick(:value)
    if keywords.present?
      Setting.commit_update_keywords = [{'keywords' => keywords, 'status_id' => status_id, 'done_ratio' => done_ratio}]
    end
    Setting.where(:name => %w(commit_fix_keywords commit_fix_status_id commit_fix_done_ratio)).delete_all
  end

  def down
    Setting.where(:name => 'commit_update_keywords').delete_all
  end
end
