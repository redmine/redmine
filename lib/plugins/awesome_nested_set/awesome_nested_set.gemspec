# -*- encoding: utf-8 -*-
require File.expand_path('../lib/awesome_nested_set/version', __FILE__)

Gem::Specification.new do |s|
  s.name = %q{awesome_nested_set}
  s.version = ::AwesomeNestedSet::VERSION
  s.authors = ["Brandon Keepers", "Daniel Morrison", "Philip Arndt"]
  s.description = %q{An awesome nested set implementation for Active Record}
  s.email = %q{info@collectiveidea.com}
  s.extra_rdoc_files = %w[README.rdoc]
  s.files = Dir.glob("lib/**/*") + %w(MIT-LICENSE README.rdoc CHANGELOG)
  s.homepage = %q{http://github.com/collectiveidea/awesome_nested_set}
  s.rdoc_options = ["--main", "README.rdoc", "--inline-source", "--line-numbers"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{An awesome nested set implementation for Active Record}
  s.license = %q{MIT}

  s.add_runtime_dependency 'activerecord', '>= 3.0.0'

  s.add_development_dependency 'rspec-rails', '~> 2.12'
  s.add_development_dependency 'rake', '~> 10'
  s.add_development_dependency 'combustion', '>= 0.3.3'
end
