class CopyRepositoriesLogEncoding < ActiveRecord::Migration[4.2]
  def self.up
    encoding = Setting.commit_logs_encoding.to_s.strip
    encoding = encoding.blank? ? 'UTF-8' : encoding
    # encoding is NULL by default
    Repository.where("type IN ('Bazaar', 'Cvs', 'Darcs')").
                 update_all(["log_encoding = ?", encoding])
  end

  def self.down
  end
end
