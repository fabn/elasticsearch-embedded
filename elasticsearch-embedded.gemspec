# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'elasticsearch/embedded/version'

Gem::Specification.new do |spec|
  spec.name          = 'elasticsearch-embedded'
  spec.version       = Elasticsearch::Embedded::VERSION
  spec.authors       = ['Fabio Napoleoni']
  spec.email         = ['f.napoleoni@gmail.com']
  spec.summary       = %q{Install an embedded version of elasticsearch into your project}
  spec.homepage      = 'https://github.com/fabn/elasticsearch-embedded'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']
  
  spec.required_ruby_version = '>= 1.9.2'

  spec.add_runtime_dependency 'ruby-progressbar', '~> 1.5.1'
  spec.add_runtime_dependency 'rubyzip', '~> 1.0.0'
  spec.add_runtime_dependency 'logging', '~> 1.8.0'

  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3.0.0'
  spec.add_development_dependency 'fakefs', '~> 0.5.0'
  spec.add_development_dependency 'elasticsearch', '~> 1.0.2'
end
