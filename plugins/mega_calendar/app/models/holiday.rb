class Holiday < ActiveRecord::Base
  unloadable
  belongs_to(:user)
  validates :start, :date => true
  validates :end, :date => true
  validates_presence_of :start, :end
  validate :validate_holiday

  def validate_holiday
    if self.start && self.end && (start_changed? || end_changed?) && self.end < self.start
      errors.add :end, :greater_than_start
    end
  end

  def self.get_activated_users
    return User.where(["users.id IN (?) AND users.login IS NOT NULL AND users.login <> ''",Setting.plugin_mega_calendar['displayed_users']]).order("users.login ASC")
  end

  def self.get_activated_groups
    return Group.all.order("users.lastname ASC")
  end
end
