lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'biryani/version'

Gem::Specification.new do |spec|
  spec.name          = 'biryani'
  spec.version       = Biryani::VERSION
  spec.authors       = ['thekuwayama']
  spec.email         = ['thekuwayama@gmail.com']
  spec.summary       = 'An HTTP/2 server implemented using Ruby Ractor'
  spec.description   = spec.summary
  spec.homepage      = 'https://github.com/thekuwayama/biryani'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>=4.0'

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler'
end
