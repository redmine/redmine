namespace :redmine do
  desc "List all permissions and the actions registered with them"
  task :permissions => :environment do
    puts "Permission Name - controller/action pairs"
    Redmine::AccessControl.permissions.sort_by {|p| p.name.to_s}.each do |permission|
      puts ":#{permission.name} - #{permission.actions.join(', ')}"
    end
  end
end
