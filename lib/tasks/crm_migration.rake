namespace :crm_migration do
  desc 'Lock all users'
  task :lock_users => :environment do
    User.unscoped.all.find_each do |user|
      if user.update!(original_status: user.status)
        user.lock!
      end
    end
  end

  desc 'Unlock all users'
  task :unlock_users => :environment do
    User.unscoped.all.find_each do |user|
      user.update(status: user.original_status)
    end
  end
end