lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/developer_device_platform/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-developer_device_platform'
  spec.version       = Fastlane::DeveloperDevicePlatform::VERSION
  spec.author        = 'ntsk'
  spec.email         = 'ntsk@ntsk.jp'

  spec.summary       = 'Run Android instrumentation tests on Google Cloud Developer Device Platform (Device Run)'
  spec.homepage      = "https://github.com/ntsk/fastlane-plugin-developer_device_platform"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w[README.md LICENSE]
  spec.require_paths = ['lib']
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.required_ruby_version = '>= 3.1'
end
