class Message < ActiveRecord::Base
  generator_for :subject, :start => 'A Message'
  generator_for :content, :start => 'Some content here'
  generator_for :board, :method => :generate_board

  def self.generate_board
    Board.generate!
  end
end
