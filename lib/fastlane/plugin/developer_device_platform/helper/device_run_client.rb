require 'fileutils'
require_relative 'gcloud'
require_relative 'session'

module Fastlane
  module DeveloperDevicePlatform
    class DeviceRunClient
      class Error < StandardError; end

      SESSION_ANNOUNCEMENT = /Creating session \[([^\]]+)\]/

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
      end
    end
  end
end
