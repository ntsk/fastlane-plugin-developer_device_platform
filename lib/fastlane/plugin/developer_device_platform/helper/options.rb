require 'fastlane/boolean'
require 'fastlane_core/configuration/config_item'
require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module DeveloperDevicePlatform
    module Options
      COLLECTION_MODES = ["always", "on-failure"].freeze
      ORIENTATIONS = ["portrait", "landscape"].freeze
      SHARDING_OPTIONS = ["uniform", "smart"].freeze
      RETRY_LEVELS = ["shard", "test"].freeze

      module_function

      def all
        execution_options + device_options + sharding_options + retry_options + behaviour_options
      end

      def execution_options
        [
          option(:gcloud_binary, "Path to the gcloud executable", default_value: "gcloud"),
          option(:project_id, "Google Cloud project ID (defaults to the active gcloud configuration)"),
          option(:service_account_key_file, "Path to a service account key JSON used to authenticate gcloud",
                 verify_block: file_exists("service_account_key_file")),
          option(:location, "Cloud location of the session", default_value: "global"),
          option(:devices, "Device type IDs to run on, e.g. [\"shiba-34\"]. One job is created per device",
                 type: Array, optional: false, verify_block: non_empty("devices")),
          option(:test_apk, "Path to the instrumentation test APK (local or gs://)",
                 optional: false, verify_block: input_exists("test_apk")),
          option(:apps, "Application files (.apk, .aab, .apks) to install before the test, in order (local or gs://)",
                 type: Array, verify_block: inputs_exist("apps")),
          option(:bucket_name, "Cloud Storage bucket for inputs and results (defaults to PROJECT_ID-devicerun)"),
          option(:test_runner_class, "Instrumentation test runner class (defaults to the one in the manifest)"),
          option(:test_targets, "Test targets, e.g. [\"class com.example.FooTest\", \"notPackage com.example.slow\"]", type: Array),
          option(:additional_test_options, "Key-value options passed to the instrumentation runner", type: Hash),
          option(:other_files_to_push, "Files to push to the device before the test, as { source => destination }", type: Hash),
          option(:paths_to_pull, "Device paths to pull after the test", type: Array),
          option(:instrumentation_timeout, "Maximum duration of the test run, 1m to 3h (default 5m)"),
          option(:orchestrator_version, "Android Test Orchestrator version, or 'auto' (unset means no orchestrator)"),
          option(:labels, "Key-value labels attached to the session", type: Hash)
        ]
      end

      def device_options
        [
          option(:locale, "Device locale in language-region form, e.g. ja-JP"),
          enum_option(:orientation, "Device orientation", ORIENTATIONS),
          option(:coordinates, "Mock GPS location as latitude,longitude"),
          enum_option(:video, "When to record a video of the screen", COLLECTION_MODES),
          enum_option(:dumpsys, "When to collect dumpsys output", COLLECTION_MODES),
          enum_option(:bugreport, "When to collect a bugreport", COLLECTION_MODES)
        ]
      end

      def sharding_options
        [
          enum_option(:sharding_option, "Sharding strategy", SHARDING_OPTIONS),
          option(:uniform_sharding_count, "Number of uniform shards (required with sharding_option 'uniform')", type: Integer),
          option(:smart_sharding_target_duration, "Target duration per shard, 2m to 1h (required with sharding_option 'smart')"),
          option(:smart_sharding_record_name, "Timing record name without extension (required with sharding_option 'smart')"),
          option(:smart_sharding_max_shard_count, "Maximum number of smart shards (0 uses the system limit)", type: Integer)
        ]
      end

      def retry_options
        [
          option(:flaky_test_attempts, "Maximum execution attempts per shard (default 1)", type: Integer),
          option(:flaky_test_parallel_retry, "Retry failures in parallel instead of sequentially", type: Boolean),
          enum_option(:flaky_test_retry_level, "Retry at the shard or the test level", RETRY_LEVELS)
        ]
      end

      def behaviour_options
        [
          option(:async, "Return the session id right after submission instead of waiting", type: Boolean, default_value: false),
          option(:download_dir, "Local directory to download the session artifacts into"),
          option(:fail_on_failure, "Fail the lane when the session result is not PASSED", type: Boolean, default_value: true)
        ]
      end

      def option(key, description, type: String, optional: true, default_value: nil, verify_block: nil)
        FastlaneCore::ConfigItem.new(
          key: key,
          env_name: "DEVELOPER_DEVICE_PLATFORM_#{key.to_s.upcase}",
          description: description,
          type: type,
          optional: optional,
          default_value: default_value,
          verify_block: verify_block
        )
      end

      def enum_option(key, description, values)
        option(key, "#{description} (#{values.join(' | ')})", verify_block: proc do |value|
          UI.user_error!("#{key} must be one of #{values.join(', ')}, got '#{value}'") unless values.include?(value)
        end)
      end

      def non_empty(name)
        proc { |value| UI.user_error!("#{name} must contain at least one entry") if value.empty? }
      end

      def file_exists(name)
        proc { |path| UI.user_error!("Could not find #{name} at path '#{path}'") unless File.exist?(path) }
      end

      def input_exists(name)
        proc { |path| UI.user_error!("Could not find #{name} at path '#{path}'") unless remote?(path) || File.exist?(path) }
      end

      def inputs_exist(name)
        proc { |paths| paths.each { |path| input_exists(name).call(path) } }
      end

      def remote?(path)
        path.start_with?("gs://")
      end
    end
  end
end
