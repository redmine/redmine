# Puma configuration for Heroku
# Heroku sets the PORT environment variable
port ENV.fetch("PORT") { 3000 }

# Use threads for better concurrency
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

# Preload the app for better performance
preload_app!

# Worker processes (Heroku recommends 1-2 workers)
workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# Heroku uses a single dyno, so we can use fewer workers
# Adjust based on your Heroku plan
if ENV.fetch("RAILS_ENV") { "development" } == "production"
  workers ENV.fetch("WEB_CONCURRENCY") { 1 }
end

# Allow puma to be restarted by `rails restart` command
plugin :tmp_restart

# Logging
if ENV["RAILS_LOG_TO_STDOUT"].present?
  stdout_redirect "/dev/stdout", "/dev/stderr", true
end

