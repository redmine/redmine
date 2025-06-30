class MailTrackerCustomLogger
  def self.logger
    Logger.new("#{Rails.root}/log/mail_tracker.log", 0, 50.megabytes)
  end
end