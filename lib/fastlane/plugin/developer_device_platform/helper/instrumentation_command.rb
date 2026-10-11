module Fastlane
  module DeveloperDevicePlatform
    class InstrumentationCommand
      module Flags
        ALTERNATE_DELIMITER = "|".freeze

        module_function

        def value(flag, value)
          value.nil? ? [] : ["--#{flag}=#{value}"]
        end

        def list(flag, values)
          values = Array(values).compact
          values.empty? ? [] : ["--#{flag}=#{join(values)}"]
        end

        def repeated(flag, values)
          Array(values).compact.map { |item| "--#{flag}=#{join([item])}" }
        end

        def dict(flag, pairs)
          (pairs || {}).map { |key, value| "--#{flag}=#{join(["#{key}=#{value}"])}" }
        end

        def boolean(flag, value)
          case value
          when true then ["--#{flag}"]
          when false then ["--no-#{flag}"]
          else []
          end
        end

        def join(items)
          items = items.map(&:to_s)
          return items.join(",") if items.none? { |item| item.include?(",") }

          "^#{ALTERNATE_DELIMITER}^#{items.join(ALTERNATE_DELIMITER)}"
        end
      end

      FLAGS = {
        devices: ["device", :list],
        test_apk: ["test", :value],
        apps: ["apps", :list],
        location: ["location", :value],
        bucket_name: ["bucket-name", :value],
        test_runner_class: ["test-runner-class", :value],
        test_targets: ["test-targets", :repeated],
        additional_test_options: ["additional-test-options", :dict],
        other_files_to_push: ["other-files-to-push", :dict],
        paths_to_pull: ["paths-to-pull", :list],
        instrumentation_timeout: ["instrumentation-timeout", :value],
        orchestrator_version: ["orchestrator-version", :value],
        locale: ["locale", :value],
        orientation: ["orientation", :value],
        coordinates: ["coordinates", :value],
        video: ["video", :value],
        dumpsys: ["dumpsys", :value],
        bugreport: ["bugreport", :value],
        sharding_option: ["sharding-option", :value],
        uniform_sharding_count: ["uniform-sharding-count", :value],
        smart_sharding_target_duration: ["smart-sharding-target-duration", :value],
        smart_sharding_record_name: ["smart-sharding-record-name", :value],
        smart_sharding_max_shard_count: ["smart-sharding-max-shard-count", :value],
        flaky_test_attempts: ["flaky-test-attempts", :value],
        flaky_test_parallel_retry: ["flaky-test-parallel-retry", :boolean],
        flaky_test_retry_level: ["flaky-test-retry-level", :value],
        labels: ["labels", :dict]
      }.freeze

      attr_reader :options

      def initialize(devices:, test_apk:, **options)
        unknown = options.keys - FLAGS.keys
        raise ArgumentError, "unknown options: #{unknown.join(', ')}" unless unknown.empty?
        raise ArgumentError, "devices must contain at least one device id" if Array(devices).compact.empty?
        raise ArgumentError, "test_apk is required" if test_apk.to_s.empty?

        @options = { devices: Array(devices), test_apk: test_apk, **options }.freeze
      end

      def arguments
        FLAGS.flat_map do |key, (flag, kind)|
          Flags.public_send(kind, flag, options[key])
        end
      end
    end
  end
end
