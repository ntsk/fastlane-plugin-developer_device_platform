require 'json'

module Fastlane
  module DeveloperDevicePlatform
    class Session
      class ParseError < StandardError; end

      CONSOLE_STORAGE_BROWSER = "https://console.cloud.google.com/storage/browser/".freeze

      module Outcome
        def done?
          status == "DONE"
        end

        def passed?
          result == "PASSED"
        end
      end

      Execution = Struct.new(:display_name, :status, :result, :message, :output_files, keyword_init: true) do
        include Outcome
      end

      Job = Struct.new(:display_name, :status, :result, :message, :output_files, :executions, keyword_init: true) do
        include Outcome
      end

      def self.parse(json)
        new(JSON.parse(json))
      rescue JSON::ParserError => e
        raise ParseError, "Could not parse session JSON: #{e.message}"
      end

      def initialize(attributes)
        @attributes = attributes
      end

      def name
        @attributes["name"]
      end

      def id
        name&.split("/")&.last || report["id"]
      end

      def status
        report.dig("status", "statusType")
      end

      def done?
        status == "DONE"
      end

      def result
        report.dig("result", "resultType")
      end

      def passed?
        result == "PASSED"
      end

      def result_message
        report.dig("result", "cause", "summary", "message")
      end

      def output_directory
        base = @attributes.dig("sessionConfig", "outputDirectoryConfig", "gcsOutputDirectory", "path")
        return nil if base.nil? || id.nil?

        "#{base.chomp('/')}/#{id}"
      end

      def console_url
        directory = output_directory
        return nil if directory.nil?

        "#{CONSOLE_STORAGE_BROWSER}#{directory.delete_prefix('gs://')}/"
      end

      def jobs
        Array(report["jobReports"]).map do |job|
          Job.new(**report_fields(job), executions: executions_of(job))
        end
      end

      def output_files
        jobs.flat_map { |job| job.output_files + job.executions.flat_map(&:output_files) }
      end

      private

      def report
        @attributes["sessionReport"] || {}
      end

      def executions_of(job)
        Array(job["executionReports"]).map { |execution| Execution.new(**report_fields(execution)) }
      end

      def report_fields(node)
        {
          display_name: node["displayName"],
          status: node.dig("status", "statusType"),
          result: node.dig("result", "resultType"),
          message: node.dig("result", "cause", "summary", "message") || Array(node.dig("status", "progressMessages")).last,
          output_files: Array(node["outputFiles"]).filter_map { |file| file.dig("gcsOutputFile", "path") }
        }
      end
    end
  end
end
