# frozen_string_literal: true

lib = Rails.root.join('lib/redmine')
Rails.autoloaders.main.push_dir lib, namespace: Redmine

IGNORE_LIST = [
  'wiki_formatting/textile/redcloth3.rb',
  'core_ext.rb',
  'core_ext'
]

class RedmineInflector < Zeitwerk::Inflector
  def camelize(basename, abspath)
    abspath.match?('redmine\/version.rb\z') ? 'VERSION' : super
  end
end

Rails.autoloaders.each do |loader|
  loader.inflector = RedmineInflector.new
  loader.inflector.inflect(
    'html' => 'HTML',
    'csv' => 'CSV',
    'pdf' => 'PDF',
    'url' => 'URL',
    'pop3' => 'POP3',
    'imap' => 'IMAP'
  )
  IGNORE_LIST.each do |mod|
    loader.ignore lib.join(mod)
  end
end
