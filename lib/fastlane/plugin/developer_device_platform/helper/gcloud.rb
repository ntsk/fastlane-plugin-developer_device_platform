require 'open3'

module Fastlane
  module DeveloperDevicePlatform
    class Gcloud
      Output = Struct.new(:stdout, :stderr, keyword_init: true)

      class CommandError < StandardError
        attr_reader :command, :stderr, :exit_status

        def initialize(command, stderr, exit_status)
          @command = command
          @stderr = stderr
          @exit_status = exit_status
          super("gcloud command failed#{" (exit #{exit_status})" if exit_status}: #{command.join(' ')}\n#{stderr}".rstrip)
        end
      end

      attr_reader :binary, :project, :credential_file

      def initialize(binary: "gcloud", project: nil, credential_file: nil)
        @binary = binary
        @project = project
        @credential_file = credential_file
      end

      def run(*args, &on_stderr_line)
        command = [binary, *args]
        stdout, stderr, status = execute(command, &on_stderr_line)
        raise CommandError.new(command, stderr, status.exitstatus) unless status.success?

        Output.new(stdout:, stderr:)
      rescue Errno::ENOENT => e
        raise CommandError.new(command, e.message, nil)
      end

      def environment
        {
          "CLOUDSDK_CORE_DISABLE_PROMPTS" => "1",
          "CLOUDSDK_CORE_PROJECT" => project,
          "CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE" => credential_file
        }.compact
      end

      private

      def execute(command)
        Open3.popen3(environment, *command) do |stdin, stdout, stderr, waiter|
          stdin.close
          stdout_reader = Thread.new { stdout.read }
          stderr_text = +""
          stderr.each_line do |line|
            stderr_text << line
            yield(line.chomp) if block_given? && !line.strip.empty?
          end
          [stdout_reader.value, stderr_text, waiter.value]
        end
      end
    end
  end
end
