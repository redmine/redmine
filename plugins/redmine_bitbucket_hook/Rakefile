require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << "test"
  files = FileList['test/**/*test.rb']
  t.test_files = files
  t.verbose = true
end

task :default => :test