### From http://svn.geekdaily.org/public/rails/plugins/generally_useful/tasks/coverage_via_rcov.rake

namespace :test do
  desc 'Measures test coverage'
  task :coverage do
    rm_f "coverage"
    rm_f "coverage.data"
    rcov = "rcov --rails --aggregate coverage.data --text-summary -Ilib --html --exclude gems/"
    files = %w(unit functional integration).map {|dir| Dir.glob("test/#{dir}/**/*_test.rb")}.flatten.join(" ")
    system("#{rcov} #{files}")
  end

  desc 'Run unit and functional scm tests'
  task :scm do
    errors = %w(test:scm:units test:scm:functionals).collect do |task|
      begin
        Rake::Task[task].invoke
        nil
      rescue => e
        task
      end
    end.compact
    abort "Errors running #{errors.to_sentence(:locale => :en)}!" if errors.any?
  end

  namespace :scm do
    namespace :setup do
      desc "Creates directory for test repositories"
      task :create_dir do
        FileUtils.mkdir_p Rails.root + '/tmp/test'
      end

      supported_scms = [:subversion, :cvs, :bazaar, :mercurial, :git, :darcs, :filesystem]

      desc "Creates a test subversion repository"
      task :subversion => :create_dir do
        repo_path = "tmp/test/subversion_repository"
        unless File.exists?(repo_path)
          system "svnadmin create #{repo_path}"
          system "gunzip < test/fixtures/repositories/subversion_repository.dump.gz | svnadmin load #{repo_path}"
        end
      end

      desc "Creates a test mercurial repository"
      task :mercurial => :create_dir do
        repo_path = "tmp/test/mercurial_repository"
        unless File.exists?(repo_path)
          bundle_path = "test/fixtures/repositories/mercurial_repository.hg"
          system "hg init #{repo_path}"
          system "hg -R #{repo_path} pull #{bundle_path}"
        end
      end

      (supported_scms - [:subversion, :mercurial]).each do |scm|
        desc "Creates a test #{scm} repository"
        task scm => :create_dir do
          unless File.exists?("tmp/test/#{scm}_repository")
            # system "gunzip < test/fixtures/repositories/#{scm}_repository.tar.gz | tar -xv -C tmp/test"
            system "tar -xvz -C tmp/test -f test/fixtures/repositories/#{scm}_repository.tar.gz"
          end
        end
      end

      desc "Creates all test repositories"
      task :all => supported_scms
    end

    desc "Updates installed test repositories"
    task :update do
      require 'fileutils'
      Dir.glob("tmp/test/*_repository").each do |dir|
        next unless File.basename(dir) =~ %r{^(.+)_repository$} && File.directory?(dir)
        scm = $1
        next unless fixture = Dir.glob("test/fixtures/repositories/#{scm}_repository.*").first
        next if File.stat(dir).ctime > File.stat(fixture).mtime

        FileUtils.rm_rf dir
        Rake::Task["test:scm:setup:#{scm}"].execute
      end
    end

    Rake::TestTask.new(:units => "db:test:prepare") do |t|
      t.libs << "test"
      t.verbose = true
      t.test_files = FileList['test/unit/repository*_test.rb'] + FileList['test/unit/lib/redmine/scm/**/*_test.rb']
    end
    Rake::Task['test:scm:units'].comment = "Run the scm unit tests"

    Rake::TestTask.new(:functionals => "db:test:prepare") do |t|
      t.libs << "test"
      t.verbose = true
      t.test_files = FileList['test/functional/repositories*_test.rb']
    end
    Rake::Task['test:scm:functionals'].comment = "Run the scm functional tests"
  end

  Rake::TestTask.new(:rdm_routing) do |t|
    t.libs << "test"
    t.verbose = true
    t.test_files = FileList['test/integration/routing/*_test.rb']
  end
  Rake::Task['test:rdm_routing'].comment = "Run the routing tests"

  Rake::TestTask.new(:ui => "db:test:prepare") do |t|
    t.libs << "test"
    t.verbose = true
    t.test_files = FileList['test/ui/**/*_test.rb']
  end
  Rake::Task['test:ui'].comment = "Run the UI tests with Capybara (PhantomJS listening on port 4444 is required)"
end
