# Loads the core plugins located in lib/plugins
Dir.glob(File.join(Rails.root, "lib/plugins/*")).sort.each do |directory|
  if File.directory?(directory)
    lib = File.join(directory, "lib")
    if File.directory?(lib)
      $:.unshift lib
      ActiveSupport::Dependencies.autoload_paths += [lib]
      # Threadsafe addition
      config.eager_load_paths += [lib]
    end
    initializer = File.join(directory, "init.rb")
    if File.file?(initializer)
      # Threadsafe modification deleted the line below initially config = config = RedmieApp::Application.config, but I am leaving it for now
      config = RedmineApp::Application.config
      eval(File.read(initializer), binding, initializer)
    end
  end
end
