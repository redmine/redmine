# frozen_string_literal: true

# Set up gems listed in the Gemfile.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

require 'bundler/setup' if File.exist?(ENV['BUNDLE_GEMFILE'])

# Explicitly load 'logger' to avoid NameError with concurrent-ruby 1.3.5.
# Reference: https://github.com/rails/rails/issues/54272
require 'logger'
