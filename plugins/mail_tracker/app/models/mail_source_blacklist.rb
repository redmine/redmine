class MailSourceBlacklist < ActiveRecord::Base
  belongs_to :user

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  before_create :downcase_email

  def downcase_email
    self.email = self.email.downcase
  end

  def self.blacklisted?(email)
    where('email = ?', email&.downcase).exists?
  end
end