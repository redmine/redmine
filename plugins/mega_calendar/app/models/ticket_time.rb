class TicketTime < ActiveRecord::Base
  unloadable
  belongs_to(:issue)
end
