# Copyright (c) 2005-2007 David Barri

require 'gloc'
require 'gloc-ruby'
require 'gloc-rails'
require 'gloc-rails-text'

require 'gloc-dev' if ENV['RAILS_ENV'] == 'development'

GLoc.set_language_mode :simple
GLoc.load_gloc_default_localized_strings
