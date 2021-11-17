# frozen_string_literal: true

# Loads the core plugins located in lib/plugins
Dir.glob(Rails.root.join('lib/plugins/*')).sort.each do |directory|
  next unless File.directory?(directory)

  initializer = File.join(directory, 'init.rb')
  if File.file?(initializer)
    config = RedmineApp::Application.config
    eval(File.read(initializer), binding, initializer)
  end
end
