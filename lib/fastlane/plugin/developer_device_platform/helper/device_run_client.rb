require 'fileutils'
require_relative 'gcloud'
require_relative 'session'

module Fastlane
  module DeveloperDevicePlatform
    class DeviceRunClient
      class Error < StandardError; end

      SESSION_ANNOUNCEMENT = /Creating session \[([^\]]+)\]/
      MINIMUM_GCLOUD_VERSION = "580.0.0".freeze

      ENVIRONMENT_HINTS = {
        /Invalid choice: 'device-run'/ =>
          "The installed gcloud does not provide the device-run command group. " \
          "Device Run requires Google Cloud CLI #{MINIMUM_GCLOUD_VERSION} or newer; run `gcloud components update`.",
        /installation of components: \[beta\]/ =>
          "The gcloud beta component is not installed; run `gcloud components install beta`."
      }.freeze

      attr_reader :gcloud

      def initialize(gcloud:)
        @gcloud = gcloud
      end

      def submit(command, &progress)
        output = device_run("sessions", "submit", "instrumentation", *command.arguments, "--async", &progress)
        output.stderr[SESSION_ANNOUNCEMENT, 1] ||
          raise(Error, "Could not find the session id in gcloud output:\n#{output.stderr}")
      end

      def wait(session_id, location:, &progress)
        device_run("sessions", "wait", session_id, "--location=#{location}", &progress)
        nil
      end

      def describe(session_id, location:)
        output = device_run("sessions", "describe", session_id, "--location=#{location}", "--full", "--format=json")
        Session.parse(output.stdout)
      end

      def download(session, destination, &progress)
        source = session.output_directory
        raise Error, "Session #{session.id} has no output directory to download" if source.nil?

        FileUtils.mkdir_p(destination)
        gcloud.run("storage", "cp", "--recursive", source, destination, &progress)
        File.join(destination, session.id)
      end

      private

      def device_run(*args, &progress)
        gcloud.run("beta", "device-run", *args, &progress)
      rescue Gcloud::CommandError => e
        hint = environment_hint(e.stderr)
        raise e unless hint

        raise Error, "#{hint}\n#{e.message}"
      end

      def environment_hint(stderr)
        ENVIRONMENT_HINTS.find { |pattern, _| pattern.match?(stderr) }&.last
      end
    end
  end
end
