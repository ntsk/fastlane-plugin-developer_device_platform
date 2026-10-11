require 'fastlane/action'
require_relative '../helper/device_run_client'
require_relative '../helper/gcloud'
require_relative '../helper/instrumentation_command'
require_relative '../helper/options'
require_relative '../helper/session_summary'

module Fastlane
  module Actions
    module SharedValues
      DEVELOPER_DEVICE_PLATFORM_SESSION_ID = :DEVELOPER_DEVICE_PLATFORM_SESSION_ID
      DEVELOPER_DEVICE_PLATFORM_RESULT = :DEVELOPER_DEVICE_PLATFORM_RESULT
      DEVELOPER_DEVICE_PLATFORM_OUTPUT_DIRECTORY = :DEVELOPER_DEVICE_PLATFORM_OUTPUT_DIRECTORY
      DEVELOPER_DEVICE_PLATFORM_CONSOLE_URL = :DEVELOPER_DEVICE_PLATFORM_CONSOLE_URL
      DEVELOPER_DEVICE_PLATFORM_DOWNLOAD_DIR = :DEVELOPER_DEVICE_PLATFORM_DOWNLOAD_DIR
    end

    class DeveloperDevicePlatformAction < Action
      COMMAND_OPTIONS = DeveloperDevicePlatform::InstrumentationCommand::FLAGS.keys
      RECOVERABLE_ERRORS = [
        DeveloperDevicePlatform::Gcloud::CommandError,
        DeveloperDevicePlatform::DeviceRunClient::Error,
        DeveloperDevicePlatform::Session::ParseError
      ].freeze

      def self.run(params)
        client = DeveloperDevicePlatform::DeviceRunClient.new(gcloud: build_gcloud(params))
        location = params[:location]

        UI.message("Submitting instrumentation session to Developer Device Platform...")
        session_id = client.submit(build_command(params)) { |line| UI.message(line) }
        lane_context[SharedValues::DEVELOPER_DEVICE_PLATFORM_SESSION_ID] = session_id
        UI.success("Created Device Run session #{session_id}")
        return session_id if params[:async]

        UI.message("Waiting for session #{session_id} to complete...")
        client.wait(session_id, location: location) { |line| UI.message(line) }
        session = client.describe(session_id, location: location)
        publish(session)
        download(client, session, params[:download_dir])
        UI.message(DeveloperDevicePlatform::SessionSummary.new(session).to_s)
        conclude(session, fail_on_failure: params[:fail_on_failure])
      rescue *RECOVERABLE_ERRORS => e
        UI.user_error!(e.message)
      end

      def self.build_gcloud(params)
        DeveloperDevicePlatform::Gcloud.new(
          binary: params[:gcloud_binary],
          project: params[:project_id],
          credential_file: params[:service_account_key_file]
        )
      end

      def self.build_command(params)
        DeveloperDevicePlatform::InstrumentationCommand.new(**COMMAND_OPTIONS.to_h { |key| [key, params[key]] })
      end

      def self.publish(session)
        lane_context[SharedValues::DEVELOPER_DEVICE_PLATFORM_RESULT] = session.result
        lane_context[SharedValues::DEVELOPER_DEVICE_PLATFORM_OUTPUT_DIRECTORY] = session.output_directory
        lane_context[SharedValues::DEVELOPER_DEVICE_PLATFORM_CONSOLE_URL] = session.console_url
      end

      def self.download(client, session, destination)
        return if destination.nil?

        UI.message("Downloading results of session #{session.id} to #{destination}...")
        local_path = client.download(session, destination) { |line| UI.verbose(line) }
        lane_context[SharedValues::DEVELOPER_DEVICE_PLATFORM_DOWNLOAD_DIR] = local_path
        UI.success("Results downloaded to #{local_path}")
      end

      def self.conclude(session, fail_on_failure:)
        outcome = "Device Run session #{session.id} finished with result #{session.result}"
        if session.passed?
          UI.success(outcome)
        elsif fail_on_failure
          UI.test_failure!(outcome)
        else
          UI.important(outcome)
        end
        session
      end

      def self.description
        "Run Android instrumentation tests on Google Cloud Developer Device Platform (Device Run)"
      end

      def self.details
        [
          "Uploads your app and test APKs to Google Cloud Storage, submits an instrumentation session to Device Run",
          "(the successor of Firebase Test Lab), waits for it to finish and reports the per-job results.",
          "Requires the Google Cloud CLI (`gcloud`) with the Device Run API (devicerun.googleapis.com) enabled on the project.",
          "Options mirror the flags of `gcloud beta device-run sessions submit instrumentation`."
        ].join(" ")
      end

      def self.authors
        ["ntsk"]
      end

      def self.return_value
        "The DeveloperDevicePlatform::Session describing the finished session, or the session id when `async` is true"
      end

      def self.output
        [
          ["DEVELOPER_DEVICE_PLATFORM_SESSION_ID", "ID of the created Device Run session"],
          ["DEVELOPER_DEVICE_PLATFORM_RESULT", "Overall result (PASSED, FAILED, ERROR, TIMED_OUT, CANCELLED)"],
          ["DEVELOPER_DEVICE_PLATFORM_OUTPUT_DIRECTORY", "Cloud Storage directory (gs://...) holding the session artifacts"],
          ["DEVELOPER_DEVICE_PLATFORM_CONSOLE_URL", "Cloud Console URL of the session artifacts"],
          ["DEVELOPER_DEVICE_PLATFORM_DOWNLOAD_DIR", "Local directory the artifacts were downloaded to, when download_dir is set"]
        ]
      end

      def self.example_code
        [
          <<~EXAMPLE,
            developer_device_platform(
              project_id: "my-gcp-project",
              devices: ["shiba-34", "tokay-36"],
              apps: ["app/build/outputs/apk/debug/app-debug.apk"],
              test_apk: "app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk",
              orchestrator_version: "auto",
              instrumentation_timeout: "15m",
              video: "on-failure",
              download_dir: "build/device-run"
            )
          EXAMPLE
          <<~EXAMPLE
            developer_device_platform(
              devices: ["mediumphone-arm-34"],
              test_apk: "gs://my-bucket/app-debug-androidTest.apk",
              apps: ["gs://my-bucket/app-debug.apk"],
              sharding_option: "smart",
              smart_sharding_target_duration: "5m",
              smart_sharding_record_name: "nightly",
              flaky_test_attempts: 2,
              flaky_test_retry_level: "test"
            )
          EXAMPLE
        ]
      end

      def self.category
        :testing
      end

      def self.is_supported?(platform)
        platform == :android
      end

      def self.available_options
        DeveloperDevicePlatform::Options.all
      end

      private_class_method :build_gcloud, :build_command, :publish, :download, :conclude
    end
  end
end
