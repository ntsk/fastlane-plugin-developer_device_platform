lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/developer_device_platform/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-developer_device_platform'
  spec.version       = Fastlane::DeveloperDevicePlatform::VERSION
  spec.author        = 'ntsk'
  spec.email         = 'contact@ntsk.jp'

  spec.summary       = 'Run Android instrumentation tests on Google Cloud Developer Device Platform (Device Run)'
  spec.homepage      = "https://github.com/ntsk/fastlane-plugin-developer_device_platform"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w[README.md LICENSE]
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 3.1'

  spec.add_development_dependency('bundler', '>= 2.4.0', '< 5.0.0')
  spec.add_development_dependency('fastlane', '>= 2.239.0')
  spec.add_development_dependency('pry', '~> 0.14')
  spec.add_development_dependency('rake', '~> 13.0')
  spec.add_development_dependency('rspec', '~> 3.12')
  spec.add_development_dependency('rspec_junit_formatter', '~> 0.6')
  spec.add_development_dependency('rubocop', '~> 1.50', '< 1.51')
  spec.add_development_dependency('rubocop-ast', '~> 1.38.0')
  spec.add_development_dependency('rubocop-performance', '~> 1.17')
  spec.add_development_dependency('rubocop-require_tools', '~> 0.1')
  spec.add_development_dependency('simplecov', '~> 0.22')

  spec.metadata['rubygems_mfa_required'] = 'true'
end
