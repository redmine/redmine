class CreateMailingMessages < ActiveRecord::Migration
  def self.up
    create_table :mailing_messages do |t|
    end
  end

  def self.down
    drop_table :mailing_messages
  end
end
