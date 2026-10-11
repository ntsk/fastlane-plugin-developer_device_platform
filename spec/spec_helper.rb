$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'simplecov'

SimpleCov.start do
  add_filter '/spec/'
end

module SpecHelper
end

require 'fastlane'
require 'fastlane/plugin/developer_device_platform'

Fastlane.load_actions
