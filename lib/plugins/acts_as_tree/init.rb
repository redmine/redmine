# Threadsafe addition
require 'active_record/acts/tree'
ActiveRecord::Base.send :include, ActiveRecord::Acts::Tree
