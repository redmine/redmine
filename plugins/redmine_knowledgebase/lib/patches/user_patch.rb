module RedmineKnowledgebase
  module Patches
    module UserPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
      end

      module InstanceMethods
        def atom_key
          return super if Redmine::VERSION.to_s >= '5.0'

          rss_key
        end
      end
    end
  end
end

unless User.included_modules.include?(RedmineKnowledgebase::Patches::UserPatch)
  User.send(:include, RedmineKnowledgebase::Patches::UserPatch)
end
