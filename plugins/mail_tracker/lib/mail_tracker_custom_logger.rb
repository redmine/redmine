class MailTrackerCustomLogger
    def self.logger
        Logger.new("#{Rails.root}/log/mail_tracker.log")
    end
end