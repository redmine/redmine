class ProjectEmail < ActiveRecord::Base
  belongs_to :project
  
  # validates_presence_of :email, :project_id
  validates_format_of :email, :with => /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}/i, :allow_blank => true, :message => "is invalid"

  def self.all_uniq_domains
    domains = pluck(:email).reject(&:blank?).map do |email|
      Mail::Address.new(email).domain
    end

    domains.uniq
  end
end
