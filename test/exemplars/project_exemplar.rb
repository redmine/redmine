class Project < ActiveRecord::Base
  generator_for :name, :start => 'Project 0'
  generator_for :identifier, :start => 'project-0000'
  generator_for :enabled_modules, :method => :all_modules
  generator_for :trackers, :method => :next_tracker

  def self.all_modules
    [].tap do |modules|
      Redmine::AccessControl.available_project_modules.each do |name|
        modules << EnabledModule.new(:name => name.to_s)
      end
    end
  end

  def self.next_tracker
    [Tracker.generate!]
  end
end
