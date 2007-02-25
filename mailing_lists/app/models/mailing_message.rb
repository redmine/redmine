class MailingMessage < ActiveRecord::Base
  belongs_to :mailing_list
  acts_as_tree :order => 'sent_on'
end
