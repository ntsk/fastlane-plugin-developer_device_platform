describe Fastlane::Actions::DeveloperDevicePlatformAction do
  let(:client) { instance_double(Fastlane::DeveloperDevicePlatform::DeviceRunClient) }
  let(:session) { Fastlane::DeveloperDevicePlatform::Session.parse(File.read(fixture_path(fixture))) }
  let(:fixture) { "session_failed.json" }
  let(:lane_context) { Fastlane::Actions.lane_context }

  before do
    allow(Fastlane::DeveloperDevicePlatform::DeviceRunClient).to receive(:new).and_return(client)
    allow(client).to receive(:submit).and_return("3f9c2a1e")
    allow(client).to receive(:wait)
    allow(client).to receive(:describe).and_return(session)
    allow(client).to receive(:download)
    lane_context.clear
  end

  def fixture_path(name)
    File.expand_path(File.join(__dir__, "..", "fixtures", name))
  end

  def run_lane(options = "")
    Fastlane::FastFile.new.parse(<<~FASTFILE).runner.execute(:test)
      lane :test do
        developer_device_platform(
          devices: ["shiba-34", "tokay-36"],
          test_apk: "#{fixture_path('fake_gcloud')}",
          apps: ["#{fixture_path('fake_gcloud')}"],
          #{options}
        )
      end
    FASTFILE
  end

  describe "a run that passes" do
    let(:fixture) { "session_passed.json" }

    it "submits, waits, describes and exposes the outcome" do
      expect(Fastlane::DeveloperDevicePlatform::DeviceRunClient).to receive(:new) do |gcloud:|
        expect(gcloud.binary).to eq("gcloud")
        expect(gcloud.project).to eq("my-project")
        expect(gcloud.credential_file).to eq(fixture_path("session_passed.json"))
        client
      end
      expect(client).to receive(:submit) do |command|
        expect(command.arguments).to include(
          "--device=shiba-34,tokay-36",
          "--test=#{fixture_path('fake_gcloud')}",
          "--apps=#{fixture_path('fake_gcloud')}",
          "--location=global",
          "--instrumentation-timeout=10m"
        )
        "3f9c2a1e"
      end
      expect(client).to receive(:wait).with("3f9c2a1e", location: "global").ordered
      expect(client).to receive(:describe).with("3f9c2a1e", location: "global").ordered

      result = run_lane(<<~OPTIONS)
        project_id: "my-project",
        service_account_key_file: "#{fixture_path('session_passed.json')}",
        instrumentation_timeout: "10m"
      OPTIONS

      expect(result).to eq(session)
      expect(lane_context[:DEVELOPER_DEVICE_PLATFORM_SESSION_ID]).to eq("3f9c2a1e")
      expect(lane_context[:DEVELOPER_DEVICE_PLATFORM_RESULT]).to eq("PASSED")
      expect(lane_context[:DEVELOPER_DEVICE_PLATFORM_OUTPUT_DIRECTORY]).to eq("gs://my-project-devicerun/automation/sessions/3f9c2a1e")
      expect(lane_context[:DEVELOPER_DEVICE_PLATFORM_CONSOLE_URL]).to end_with("/automation/sessions/3f9c2a1e/")
      expect(lane_context[:DEVELOPER_DEVICE_PLATFORM_DOWNLOAD_DIR]).to be_nil
    end

    it "downloads results when download_dir is given" do
      expect(client).to receive(:download).with(session, "build/device-run").and_return("build/device-run/3f9c2a1e")

      run_lane('download_dir: "build/device-run"')

      expect(lane_context[:DEVELOPER_DEVICE_PLATFORM_DOWNLOAD_DIR]).to eq("build/device-run/3f9c2a1e")
    end
  end

  describe "a run that fails" do
    it "raises a user error after exposing the outcome" do
      expect { run_lane }.to raise_error(FastlaneCore::Interface::FastlaneTestFailure, /FAILED/)

      expect(lane_context[:DEVELOPER_DEVICE_PLATFORM_SESSION_ID]).to eq("3f9c2a1e")
      expect(lane_context[:DEVELOPER_DEVICE_PLATFORM_RESULT]).to eq("FAILED")
    end

    it "still downloads results before raising" do
      expect(client).to receive(:download).with(session, "out").and_return("out/3f9c2a1e")

      expect { run_lane('download_dir: "out"') }.to raise_error(FastlaneCore::Interface::FastlaneTestFailure)
      expect(lane_context[:DEVELOPER_DEVICE_PLATFORM_DOWNLOAD_DIR]).to eq("out/3f9c2a1e")
    end

    it "returns the session instead of raising when fail_on_failure is false" do
      expect(run_lane("fail_on_failure: false")).to eq(session)
    end
  end

  describe "an asynchronous run" do
    it "returns right after submission without waiting" do
      expect(client).not_to receive(:wait)
      expect(client).not_to receive(:describe)

      expect(run_lane("async: true")).to eq("3f9c2a1e")
      expect(lane_context[:DEVELOPER_DEVICE_PLATFORM_SESSION_ID]).to eq("3f9c2a1e")
      expect(lane_context[:DEVELOPER_DEVICE_PLATFORM_RESULT]).to be_nil
    end
  end

  describe "option validation" do
    it "rejects an unknown video mode" do
      expect { run_lane('video: "sometimes"') }.to raise_error(FastlaneCore::Interface::FastlaneError, /video/)
    end

    it "rejects an unknown orientation" do
      expect { run_lane('orientation: "upside-down"') }.to raise_error(FastlaneCore::Interface::FastlaneError, /orientation/)
    end

    it "rejects a sharding option other than uniform or smart" do
      expect { run_lane('sharding_option: "random"') }.to raise_error(FastlaneCore::Interface::FastlaneError, /sharding_option/)
    end

    it "rejects a missing test apk" do
      expect do
        Fastlane::FastFile.new.parse(<<~FASTFILE).runner.execute(:test)
          lane :test do
            developer_device_platform(devices: ["shiba-34"], test_apk: "does/not/exist.apk")
          end
        FASTFILE
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /exist\.apk/)
    end

    it "accepts gs:// paths without checking the local filesystem" do
      expect(client).to receive(:submit) do |command|
        expect(command.arguments).to include("--test=gs://bucket/test.apk", "--apps=gs://bucket/app.apk")
        "3f9c2a1e"
      end

      Fastlane::FastFile.new.parse(<<~FASTFILE).runner.execute(:test)
        lane :test do
          developer_device_platform(devices: ["shiba-34"], test_apk: "gs://bucket/test.apk", apps: ["gs://bucket/app.apk"], fail_on_failure: false)
        end
      FASTFILE
    end
  end

  describe "gcloud failures" do
    it "surfaces gcloud errors as user errors" do
      command = ["gcloud", "beta", "device-run"]
      error = Fastlane::DeveloperDevicePlatform::Gcloud::CommandError.new(command, "ERROR: permission denied", 1)
      allow(client).to receive(:submit).and_raise(error)

      expect { run_lane }.to raise_error(FastlaneCore::Interface::FastlaneError, /permission denied/)
    end
  end

  it "declares metadata" do
    expect(described_class.description).to be_a(String)
    expect(described_class.authors).to eq(["ntsk"])
    expect(described_class.is_supported?(:android)).to be(true)
    expect(described_class.is_supported?(:ios)).to be(false)
    expect(described_class.output.map(&:first)).to include(
      "DEVELOPER_DEVICE_PLATFORM_SESSION_ID",
      "DEVELOPER_DEVICE_PLATFORM_RESULT",
      "DEVELOPER_DEVICE_PLATFORM_OUTPUT_DIRECTORY",
      "DEVELOPER_DEVICE_PLATFORM_CONSOLE_URL",
      "DEVELOPER_DEVICE_PLATFORM_DOWNLOAD_DIR"
    )
    expect(described_class.example_code).not_to be_empty
  end
end
