# frozen_string_literal: true

# Rack 3.1.14 or later sets default limits of 4MB for query string bytesize
# and 4096 for the number of query parameters. These limits are too low
# for Redmine and can cause the following issues:
#
# - The low bytesize limit prevents the mail handler from processing incoming
#   emails larger than 4MB (https://www.redmine.org/issues/42962)
# - The low parameter limit prevents saving workflows with many statuses
#   (https://www.redmine.org/issues/42875)
#
# See also:
# - https://github.com/rack/rack/blob/v3.1.16/README.md#configuration
# - https://github.com/rack/rack/blob/v3.1.16/lib/rack/query_parser.rb#L54
# - https://github.com/rack/rack/blob/v3.1.16/lib/rack/query_parser.rb#L57
ENV['RACK_QUERY_PARSER_BYTESIZE_LIMIT'] ||= '33554432'
ENV['RACK_QUERY_PARSER_PARAMS_LIMIT'] ||= '65536'

# Set up gems listed in the Gemfile.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

require 'bundler/setup' if File.exist?(ENV['BUNDLE_GEMFILE'])
