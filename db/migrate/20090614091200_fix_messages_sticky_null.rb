class FixMessagesStickyNull < ActiveRecord::Migration
  def self.up
    Message.where('sticky IS NULL').update_all('sticky = 0')
  end

  def self.down
    # nothing to do
  end
end
