# frozen_string_literal: false

begin
  require 'metric_fu'
rescue LoadError
  # Metric-fu not installed
  # http://metric-fu.rubyforge.org/
end
