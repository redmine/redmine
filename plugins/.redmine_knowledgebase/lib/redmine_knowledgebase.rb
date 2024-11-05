REQUIRED_FILES = [
  'active_record/acts/rated.rb',
  'active_record/acts/versioned.rb',
  'concerns/knowledgebase_project_extension',
  'helpers/knowledgebase_link_helper',
  'helpers/knowledgebase_settings_helper',
  'patches/user_patch',
  'macros',
]

base_url = File.dirname(__FILE__)
REQUIRED_FILES.each { |file| require(base_url + '/' + file) }

module RedmineKnowledgebase
end
