begin
  require 'yard'

  YARD::Rake::YardocTask.new do |t|
    files = ['app/**/*.rb']
    files << Dir['lib/**/*.rb', 'plugins/**/*.rb'].reject {|f| f.match(/test/) }
    t.files = files

    static_files = ['doc/CHANGELOG',
                    'doc/COPYING',
                    'doc/INSTALL',
                    'doc/RUNNING_TESTS',
                    'doc/UPGRADING'].join(',')

    t.options += ['--output-dir', './doc/app', '--files', static_files]
  end

rescue LoadError
  # yard not installed (gem install yard)
  # http://yardoc.org
end
