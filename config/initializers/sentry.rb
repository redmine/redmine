Sentry.init do |config|
  config.dsn = 'https://41a3267f75c64181be164a26e9c327c3:9da66cee28ae4d5ca309b0bc40ee5333@sentry.io/157674'
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.enabled_environments = %w[]

  # Set tracesSampleRate to 1.0 to capture 100%
  # of transactions for performance monitoring.
  # We recommend adjusting this value in production
  config.traces_sample_rate = 1.0
  # or
  config.traces_sampler = lambda do |context|
    true
  end
end
