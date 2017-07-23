class PopulateChangesetsUserId < ActiveRecord::Migration[4.2]
  def self.up
    committers = Changeset.connection.select_values("SELECT DISTINCT committer FROM #{Changeset.table_name}")
    committers.each do |committer|
      next if committer.blank?
      if committer.strip =~ /^([^<]+)(<(.*)>)?$/
        username, email = $1.strip, $3
        u = User.find_by_login(username)
        u ||= User.find_by_mail(email) unless email.blank?
        Changeset.where(["committer = ?", committer]).update_all("user_id = #{u.id}") unless u.nil?
      end
    end
  end

  def self.down
    Changeset.update_all('user_id = NULL')
  end
end
