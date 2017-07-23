class SerializePossiblesValues < ActiveRecord::Migration[4.2]
  def self.up
    CustomField.all.each do |field|
      if field.possible_values and field.possible_values.is_a? String
        field.possible_values = field.possible_values.split('|')
        field.save
      end
    end
  end

  def self.down
  end
end
