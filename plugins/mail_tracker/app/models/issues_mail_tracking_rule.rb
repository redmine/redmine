class IssuesMailTrackingRule < ActiveRecord::Base
  unloadable
  belongs_to :issue
  belongs_to :mail_tracking_rule
end