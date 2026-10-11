require 'terminal-table'
require_relative 'session'

module Fastlane
  module DeveloperDevicePlatform
    class SessionSummary
      HEADINGS = ["JOB", "EXECUTION", "RESULT"].freeze

      attr_reader :session

      def initialize(session)
        @session = session
      end

      def rows
        session.jobs.flat_map do |job|
          if job.executions.empty?
            [[job.display_name, "", describe(job)]]
          else
            job.executions.map { |execution| [job.display_name, execution.display_name, describe(execution)] }
          end
        end
      end

      def to_s
        lines = [headline, session.result_message]
        lines << Terminal::Table.new(headings: HEADINGS, rows: rows).to_s unless rows.empty?
        lines << "Result files: #{session.console_url}" if session.console_url
        lines.compact.join("\n")
      end

      private

      def headline
        if session.done?
          "Session #{session.id} finished with result #{session.result}"
        else
          "Session #{session.id} is #{session.status}"
        end
      end

      def describe(report)
        return report.result if report.passed?

        [report.result, report.message].compact.join(": ")
      end
    end
  end
end
