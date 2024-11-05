#!/usr/bin/env ruby
#
# refresh.rb
# (c) 2011, Alex Bevilacqua
#
# This script takes all yaml localization files in the target directory
# (as defined by PATH) and re-orders them so that they appear in 
# alphabetical order.
# It also takes the control (primary) localization file and injects any keys
# that may be missing from the derivative files.
#
# TODO don't discard comments
# TODO don't discard other elements in the file that don't match
#      hash.keys.first
###############################################################################
$KCODE = 'UTF8' unless RUBY_VERSION >= '1.9'

require 'rubygems'
require 'yaml'
require 'ya2yaml'

# The location of the locale files
PATH = "config/locales/"

# The "control" file is the one we assume will always have the latest
# translatable fields that should be copied to all other translation files
CONTROL = "en.yml"

class Hash
  # Replacing the to_yaml function so it'll serialize hashes sorted (by their keys)
  #
  # Original function is in /usr/lib/ruby/1.8/yaml/rubytypes.rb
  def to_yaml( opts = {} )
    YAML::quick_emit( object_id, opts ) do |out|
      out.map( taguri, to_yaml_style ) do |map|
        # sort keys alphabetically
        sort.each do |k, v|
          map.add( k, v )
        end
      end
    end
  end
end

# open the control file before processing the file list
ctrl = YAML::load(File.open(PATH + CONTROL))

# iterate over each YAML file in the target directory
Dir["#{PATH}*.yml"].each do |lang|  
  puts "Processing #{lang} ..."
  data = YAML::load(File.open(lang))
  
  unless lang == CONTROL
    # Fill the current translation template with any keys that may be missing
    # from the control template
    # We assume that the YAML structure will always be:
    #   lang:
    #     entry_1: value
    #     entry_2: value
    # so we fetch the first hash value and work the it's children
    ctrl["#{ctrl.keys.first}"].each do |c|
      data["#{data.keys.first}"][c[0]] = c[1] unless data["#{data.keys.first}"].has_key?(c[0])
    end
  end
  
  # overwrite the original file with the sorted and refreshed translation files
  file = File.open(lang, 'w')
  file.write(data.ya2yaml(:syck_compatible => true))
  file.close
end
