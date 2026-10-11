describe Fastlane::DeveloperDevicePlatform::DeviceRunClient do
  let(:gcloud) { instance_double(Fastlane::DeveloperDevicePlatform::Gcloud) }
  let(:client) { described_class.new(gcloud: gcloud) }
  let(:command) do
    Fastlane::DeveloperDevicePlatform::InstrumentationCommand.new(devices: ["shiba-34"], test_apk: "test.apk", location: "global")
  end
  let(:session_json) { File.read(File.join(__dir__, "..", "fixtures", "session_failed.json")) }

  def output(stdout: "", stderr: "")
    Fastlane::DeveloperDevicePlatform::Gcloud::Output.new(stdout:, stderr:)
  end

  describe "#submit" do
    let(:submit_stderr) do
      <<~STDERR
        Uploading [test.apk].

        Initiated long-running operation [operation-123] to create session.
        Creating session [3f9c2a1e] in location [global].
        Result files will be stored at [https://console.cloud.google.com/storage/browser/b/automation/sessions/3f9c2a1e/].
      STDERR
    end

    it "submits asynchronously and returns the session id announced by gcloud" do
      expect(gcloud).to receive(:run)
        .with("beta", "device-run", "sessions", "submit", "instrumentation", *command.arguments, "--async")
        .and_return(output(stderr: submit_stderr))

      expect(client.submit(command)).to eq("3f9c2a1e")
    end

    it "raises when gcloud did not announce a session id" do
      allow(gcloud).to receive(:run).and_return(output(stderr: "Uploading [test.apk].\n"))

      expect { client.submit(command) }.to raise_error(described_class::Error, /session id/i)
    end
  end

  describe "when gcloud cannot run device-run commands" do
    def command_error(stderr)
      Fastlane::DeveloperDevicePlatform::Gcloud::CommandError.new(%w[gcloud beta device-run sessions wait x], stderr, 2)
    end

    it "explains that the installed gcloud is too old when device-run is not a known command" do
      allow(gcloud).to receive(:run).and_raise(command_error("ERROR: (gcloud.beta) Invalid choice: 'device-run'.\n"))

      expect { client.wait("x", location: "global") }
        .to raise_error(described_class::Error, /Google Cloud CLI 580\.0\.0 or newer/)
    end

    it "explains how to install the beta component when it is missing" do
      stderr = "ERROR: (gcloud) You do not currently have this command group installed. " \
               "Using it requires the installation of components: [beta]\n"
      allow(gcloud).to receive(:run).and_raise(command_error(stderr))

      expect { client.wait("x", location: "global") }
        .to raise_error(described_class::Error, /gcloud components install beta/)
    end

    it "passes other gcloud failures through untouched" do
      allow(gcloud).to receive(:run).and_raise(command_error("ERROR: PERMISSION_DENIED\n"))

      expect { client.wait("x", location: "global") }
        .to raise_error(Fastlane::DeveloperDevicePlatform::Gcloud::CommandError, /PERMISSION_DENIED/)
    end
  end

  describe "#wait" do
    it "blocks on the session in the given location" do
      expect(gcloud).to receive(:run)
        .with("beta", "device-run", "sessions", "wait", "3f9c2a1e", "--location=us-central1")
        .and_return(output)

      client.wait("3f9c2a1e", location: "us-central1")
    end
  end

  describe "#cancel" do
    it "cancels the session in the given location" do
      expect(gcloud).to receive(:run)
        .with("beta", "device-run", "sessions", "cancel", "3f9c2a1e", "--location=global")
        .and_return(output)

      client.cancel("3f9c2a1e", location: "global")
    end
  end

  describe "#describe" do
    it "fetches the full session as json and parses it" do
      expect(gcloud).to receive(:run)
        .with("beta", "device-run", "sessions", "describe", "3f9c2a1e", "--location=global", "--full", "--format=json")
        .and_return(output(stdout: session_json))

      session = client.describe("3f9c2a1e", location: "global")

      expect(session).to be_a(Fastlane::DeveloperDevicePlatform::Session)
      expect(session.id).to eq("3f9c2a1e")
      expect(session.result).to eq("FAILED")
    end
  end

  describe "#download" do
    let(:session) { Fastlane::DeveloperDevicePlatform::Session.parse(session_json) }

    it "copies the session output directory into the destination and returns the local path" do
      Dir.mktmpdir do |dir|
        destination = File.join(dir, "results")
        expect(gcloud).to receive(:run)
          .with("storage", "cp", "--recursive", "gs://my-project-devicerun/automation/sessions/3f9c2a1e", destination)
          .and_return(output)

        expect(client.download(session, destination)).to eq(File.join(destination, "3f9c2a1e"))
        expect(File).to be_directory(destination)
      end
    end

    it "refuses to download a session without an output directory" do
      bare = Fastlane::DeveloperDevicePlatform::Session.new({ "name" => "projects/p/locations/global/sessions/x" })

      expect { client.download(bare, "/tmp/whatever") }.to raise_error(described_class::Error, /output directory/)
    end
  end
end
