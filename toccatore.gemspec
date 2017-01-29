require "date"
require File.expand_path("../lib/toccatore/version", __FILE__)

Gem::Specification.new do |s|
  s.authors       = "Martin Fenner"
  s.email         = "mfenner@datacite.org"
  s.name          = "toccatore"
  s.homepage      = "https://github.com/datacite/toccatore"
  s.summary       = "Ruby library to find ORCID IDs in the DataCite Solr index"
  s.date          = Date.today
  s.description   = "Ruby library to find ORCID IDs in the DataCite Solr index."
  s.require_paths = ["lib"]
  s.version       = Toccatore::VERSION
  s.extra_rdoc_files = ["README.md"]
  s.license       = 'MIT'

  # Declary dependencies here, rather than in the Gemfile
  s.add_dependency 'maremma', '~> 3.1'
  s.add_dependency 'activesupport', '~> 4.2', '>= 4.2.5'
  s.add_dependency 'dotenv', '~> 2.1', '>= 2.1.1'
  s.add_dependency 'namae', '~> 0.11.0'
  s.add_dependency 'gender_detector', '~> 1.0'
  s.add_dependency 'thor', '~> 0.19'
  s.add_development_dependency 'bundler', '~> 1.0'
  s.add_development_dependency 'rspec', '~> 3.4'
  s.add_development_dependency 'rake', '~> 12.0'
  s.add_development_dependency 'rack-test', '~> 0'
  s.add_development_dependency 'vcr', '~> 3.0', '>= 3.0.3'
  s.add_development_dependency 'webmock', '~> 1.22', '>= 1.22.3'
  s.add_development_dependency 'codeclimate-test-reporter', '~> 1.0', '>= 1.0.0'
  s.add_development_dependency 'simplecov', '~> 0.12.0'

  s.require_paths = ["lib"]
  s.files       = `git ls-files`.split($/)
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = ["toccatore"]
end
