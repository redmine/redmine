# frozen_string_literal: true

# Rack 3.1.14 or later limits query parameters to 4096 by default, which
# prevents saving workflows with many statuses.
# Setting RACK_QUERY_PARSER_PARAMS_LIMIT to 65536 allows handling up to
# approximately 100 statuses.
#
# See also:
# - https://www.redmine.org/issues/42875
# - https://github.com/rack/rack/blob/v3.1.16/README.md#configuration
# - https://github.com/rack/rack/blob/v3.1.16/lib/rack/query_parser.rb#L57
ENV['RACK_QUERY_PARSER_PARAMS_LIMIT'] ||= '65536'

# Set up gems listed in the Gemfile.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

require 'bundler/setup' if File.exist?(ENV['BUNDLE_GEMFILE'])
