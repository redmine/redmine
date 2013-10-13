class SupportForMultipleCommitKeywords < ActiveRecord::Migration
  def up
    # Replaces commit_fix_keywords, commit_fix_status_id, commit_fix_done_ratio settings
    # with commit_update_keywords setting
    keywords = Setting.where(:name => 'commit_fix_keywords').limit(1).pluck(:value).first
    status_id = Setting.where(:name => 'commit_fix_status_id').limit(1).pluck(:value).first
    done_ratio = Setting.where(:name => 'commit_fix_done_ratio').limit(1).pluck(:value).first
    if keywords.present?
      Setting.commit_update_keywords = [{'keywords' => keywords, 'status_id' => status_id, 'done_ratio' => done_ratio}]
    end
    Setting.where(:name => %w(commit_fix_keywords commit_fix_status_id commit_fix_done_ratio)).delete_all
  end

  def down
    Setting.where(:name => 'commit_update_keywords').delete_all
  end
end
