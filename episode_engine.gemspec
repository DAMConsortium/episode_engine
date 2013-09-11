# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'episode_engine/version'

Gem::Specification.new do |spec|
  spec.name          = 'episode_engine'
  spec.version       = EpisodeEngine::VERSION
  spec.authors       = ['John Whitson']
  spec.email         = %w(john.whitson@gmail.com)
  spec.description   = %q{A library to interact with Telestream's Episode Engine product.}
  spec.summary       = %q{}
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = %w(lib)

  spec.add_dependency 'eventmachine'

  # Roo requirement to assess google spreadsheets
  spec.add_dependency 'google_drive'
  spec.add_dependency 'zip' # Required by google_drive gem


  spec.add_dependency 'mongo'
  spec.add_dependency 'net-ssh'
  spec.add_dependency 'roo'

  # MIG GEM REQUIREMENT. REMOVE ONCE MIG HAS BEEN DEPLOYED AS A GEM
  spec.add_dependency 'ruby-filemagic'

  spec.add_dependency 'sinatra'
  spec.add_dependency 'xml-simple'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'bson_ext'
end
