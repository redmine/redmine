# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

namespace :test do
  desc 'Measures test coverage'
  task :coverage do
    rm_f "coverage"
    ENV["COVERAGE"] = "1"
    Rake::Task["test"].invoke
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
      task :create_dir => :environment do
        FileUtils.mkdir_p Rails.root + '/tmp/test'
      end

      supported_scms = [:subversion, :cvs, :bazaar, :mercurial, :git, :git_utf8, :filesystem]

      desc "Creates a test subversion repository"
      task :subversion => :create_dir do
        repo_path = "tmp/test/subversion_repository"
        unless File.exist?(repo_path)
          system "svnadmin create #{repo_path}"
          system "gunzip < test/fixtures/repositories/subversion_repository.dump.gz | svnadmin load #{repo_path}"
        end
      end

      desc "Creates a test mercurial repository"
      task :mercurial => :create_dir do
        repo_path = "tmp/test/mercurial_repository"
        unless File.exist?(repo_path)
          bundle_path = "test/fixtures/repositories/mercurial_repository.hg"
          system "hg init #{repo_path}"
          system "hg -R #{repo_path} pull #{bundle_path}"
        end
      end

      def extract_tar_gz(prefix)
        unless File.exist?("tmp/test/#{prefix}_repository")
          # system "gunzip < test/fixtures/repositories/#{prefix}_repository.tar.gz | tar -xv -C tmp/test"
          system "tar -xvz -C tmp/test -f test/fixtures/repositories/#{prefix}_repository.tar.gz"
        end
      end

      (supported_scms - [:subversion, :mercurial]).each do |scm|
        desc "Creates a test #{scm} repository"
        task scm => :create_dir do
          extract_tar_gz(scm)
        end
      end

      desc "Creates all test repositories"
      task :all => supported_scms
    end

    desc "Updates installed test repositories"
    task :update => :environment do
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

    task(:units => "db:test:prepare") do |t|
      $: << "test"
      Rails::TestUnit::Runner.run_from_rake 'test', FileList['test/unit/repository*_test.rb'] + FileList['test/unit/lib/redmine/scm/**/*_test.rb']
    end
    Rake::Task['test:scm:units'].comment = "Run the scm unit tests"

    task(:functionals => "db:test:prepare") do |t|
      $: << "test"
      Rails::TestUnit::Runner.run_from_rake 'test', FileList['test/functional/repositories*_test.rb']
    end
    Rake::Task['test:scm:functionals'].comment = "Run the scm functional tests"
  end

  task(:routing) do |t|
    $: << "test"
    Rails::TestUnit::Runner.run_from_rake 'test', FileList['test/integration/routing/*_test.rb'] + FileList['test/integration/api_test/*_routing_test.rb']
  end
  Rake::Task['test:routing'].comment = "Run the routing tests"

  task(:autoload) do |t|
    $: << "test"
    ENV["REDMINE_PLUGINS_DIRECTORY"] = "test/fixtures/plugins"
    Rails::TestUnit::Runner.run_from_rake 'test', FileList['test/autoload/*_test.rb']
  end
  Rake::Task['test:autoload'].comment = "Run the plugin autoload tests"
end
