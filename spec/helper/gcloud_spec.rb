describe Fastlane::DeveloperDevicePlatform::Gcloud do
  let(:binary) { File.join(__dir__, "..", "fixtures", "fake_gcloud") }

  around do |example|
    saved = ENV.to_h.slice("FAKE_GCLOUD_EXIT", "FAKE_GCLOUD_STDERR")
    example.run
  ensure
    ENV.delete("FAKE_GCLOUD_EXIT")
    ENV.delete("FAKE_GCLOUD_STDERR")
    ENV.update(saved)
  end

  it "runs the binary with the given arguments and captures stdout and stderr" do
    output = described_class.new(binary: binary).run("beta", "device-run", "sessions", "list")

    expect(output.stdout.lines(chomp: true)).to start_with("beta", "device-run", "sessions", "list")
    expect(output.stderr).to eq("first stderr line\nsecond stderr line\n")
  end

  it "disables prompts and passes the project and credential file through the environment" do
    output = described_class.new(binary: binary, project: "my-project", credential_file: "/tmp/key.json").run("version")

    expect(output.stdout).to include("project=my-project", "credential=/tmp/key.json", "prompts=1")
  end

  it "leaves project and credential unset when not configured" do
    output = described_class.new(binary: binary).run("version")

    expect(output.stdout).to include("project=\n", "credential=\n")
  end

  it "streams stderr lines to the given block" do
    lines = []
    described_class.new(binary: binary).run("version") { |line| lines << line }

    expect(lines).to eq(["first stderr line", "second stderr line"])
  end

  it "does not stream blank stderr lines but keeps them in the captured output" do
    ENV["FAKE_GCLOUD_STDERR"] = "Uploading [test.apk].\n\nCreating session [abc] in location [global]."
    lines = []

    output = described_class.new(binary: binary).run("version") { |line| lines << line }

    expect(lines).to eq(["Uploading [test.apk].", "Creating session [abc] in location [global].", "second stderr line"])
    expect(output.stderr).to include("\n\n")
  end

  it "raises an error carrying the command and stderr when the exit status is non-zero" do
    ENV["FAKE_GCLOUD_EXIT"] = "2"
    ENV["FAKE_GCLOUD_STDERR"] = "ERROR: (gcloud.beta.device-run) something broke"

    expect { described_class.new(binary: binary).run("beta", "device-run") }
      .to raise_error(described_class::CommandError) { |error|
        expect(error.message).to include("beta device-run", "something broke")
        expect(error.stderr).to include("something broke")
        expect(error.exit_status).to eq(2)
      }
  end

  it "raises a descriptive error when the binary cannot be found" do
    expect { described_class.new(binary: "/nonexistent/gcloud").run("version") }
      .to raise_error(described_class::CommandError, %r{/nonexistent/gcloud})
  end
end
