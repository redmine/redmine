class Board < ActiveRecord::Base
  generator_for :name, :start => 'A Forum'
  generator_for :description, :start => 'Some description here'
  generator_for :project, :method => :generate_project

  def self.generate_project
    Project.generate!
  end
end
