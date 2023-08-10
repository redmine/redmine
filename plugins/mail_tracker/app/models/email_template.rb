class EmailTemplate < ActiveRecord::Base
  unloadable

  KEYWORDS = [
    '###ISSUE_LINK###',
    '###USERNAME_LT###',
    '###USERNAME_EN###'
  ].freeze

  def converted_body(issue_link, username)
    new_body = self.body

    KEYWORDS.each do |key|
      next unless new_body.include?(key)
      case key
      when '###ISSUE_LINK###'
        new_body.gsub!(key, "+*\"#{issue_link.split('/').last}\":#{issue_link}*+")
      when '###USERNAME_LT###'
        new_body.gsub!(key, username == "mail_no_username" ? I18n.t(username.to_sym, locale: :lt) : username)
      when '###USERNAME_EN###'
        new_body.gsub!(key, username == "mail_no_username" ? I18n.t(username.to_sym, locale: :en) : username)
      end
    end

    new_body
  end

  def self.domains_without_template
    available_domains = ProjectEmail.all_uniq_domains
    domains_with_templates = where.not(domain: 'Default').pluck(:domain)
    available_domains - domains_with_templates
  end

  def self.template_by_domain(domain: )
    record = EmailTemplate.find_by(domain: domain)
    record = EmailTemplate.find_by(domain: 'Default') if record.nil?
    record
  end
end