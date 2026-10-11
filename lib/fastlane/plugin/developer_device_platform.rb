require 'fastlane/plugin/developer_device_platform/version'

module Fastlane
  module DeveloperDevicePlatform
    def self.all_classes
      Dir[File.expand_path('**/{actions,helper}/*.rb', File.dirname(__FILE__))]
    end
  end
end

Fastlane::DeveloperDevicePlatform.all_classes.each do |current|
  require current
end
