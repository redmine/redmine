require ::File.expand_path('../config/environment',  __FILE__)

map Redmine::Utils.relative_url_root || '/' do
  run RedmineApp::Application
end
