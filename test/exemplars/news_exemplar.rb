class News < ActiveRecord::Base
  generator_for :title, :start => 'A New Item'
  generator_for :description, :start => 'Some content here'

end
