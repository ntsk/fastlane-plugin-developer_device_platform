source('https://rubygems.org')

gem 'bundler'
gem 'fastlane', '>= 2.239.0'
gem 'pry'
gem 'rake'
gem 'rspec'
gem 'rubocop', '1.50.2'
gem 'rubocop-ast', '~> 1.38.0'
gem 'rubocop-performance'
gem 'rubocop-require_tools'
gem 'simplecov'

gemspec

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
