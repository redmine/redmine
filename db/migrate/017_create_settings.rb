class CreateSettings < ActiveRecord::Migration[4.2]
  def self.up
    create_table :settings, :force => true do |t|
      t.column "name", :string, :limit => 30, :default => "", :null => false
      t.column "value", :text
    end

    # Persist text_formatting default setting for new installations
    setting = Setting.new(:name => "text_formatting", :value => Setting.text_formatting)
    setting.save!
  end

  def self.down
    drop_table :settings
  end
end
