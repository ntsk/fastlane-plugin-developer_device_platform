describe Fastlane::DeveloperDevicePlatform::InstrumentationCommand do
  let(:required) { { devices: ["shiba-34"], test_apk: "test.apk" } }

  def arguments(**options)
    described_class.new(**required, **options).arguments
  end

  describe "#arguments" do
    it "emits only the required flags by default" do
      expect(arguments).to eq(["--device=shiba-34", "--test=test.apk"])
    end

    it "joins multiple devices with commas" do
      expect(arguments(devices: ["shiba-34", "tokay-36"])).to include("--device=shiba-34,tokay-36")
    end

    it "joins apps with commas and keeps their order" do
      expect(arguments(apps: ["app.apk", "helper.apk"])).to include("--apps=app.apk,helper.apk")
    end

    it "switches to an alternate delimiter when a list value contains a comma" do
      expect(arguments(apps: ["a,b.apk", "c.apk"])).to include("--apps=^|^a,b.apk|c.apk")
    end

    it "omits empty lists and hashes" do
      expect(arguments(apps: [], labels: {}, paths_to_pull: nil)).to eq(["--device=shiba-34", "--test=test.apk"])
    end

    it "emits scalar flags verbatim" do
      args = arguments(
        location: "us-central1",
        bucket_name: "my-bucket",
        test_runner_class: "androidx.test.runner.AndroidJUnitRunner",
        instrumentation_timeout: "10m",
        orchestrator_version: "auto",
        locale: "ja-JP",
        orientation: "landscape",
        coordinates: "35.6812,139.7671",
        video: "on-failure",
        dumpsys: "always",
        bugreport: "on-failure",
        flaky_test_attempts: 3,
        flaky_test_retry_level: "test"
      )

      expect(args).to include(
        "--location=us-central1",
        "--bucket-name=my-bucket",
        "--test-runner-class=androidx.test.runner.AndroidJUnitRunner",
        "--instrumentation-timeout=10m",
        "--orchestrator-version=auto",
        "--locale=ja-JP",
        "--orientation=landscape",
        "--coordinates=35.6812,139.7671",
        "--video=on-failure",
        "--dumpsys=always",
        "--bugreport=on-failure",
        "--flaky-test-attempts=3",
        "--flaky-test-retry-level=test"
      )
    end

    it "emits sharding flags" do
      args = arguments(
        sharding_option: "smart",
        smart_sharding_target_duration: "5m",
        smart_sharding_record_name: "nightly",
        smart_sharding_max_shard_count: 4
      )

      expect(args).to include(
        "--sharding-option=smart",
        "--smart-sharding-target-duration=5m",
        "--smart-sharding-record-name=nightly",
        "--smart-sharding-max-shard-count=4"
      )
      expect(arguments(sharding_option: "uniform", uniform_sharding_count: 2)).to include(
        "--sharding-option=uniform", "--uniform-sharding-count=2"
      )
    end

    it "emits a boolean flag in gcloud's --[no-] form" do
      expect(arguments(flaky_test_parallel_retry: true)).to include("--flaky-test-parallel-retry")
      expect(arguments(flaky_test_parallel_retry: false)).to include("--no-flaky-test-parallel-retry")
      expect(arguments(flaky_test_parallel_retry: nil).grep(/parallel-retry/)).to be_empty
    end

    it "repeats --test-targets once per target" do
      args = arguments(test_targets: ["class com.example.FooTest", "notPackage com.example.slow"])

      expect(args).to include("--test-targets=class com.example.FooTest", "--test-targets=notPackage com.example.slow")
    end

    it "repeats dictionary flags once per pair and accepts symbol keys" do
      args = arguments(
        additional_test_options: { clearPackageData: "true", "coverage" => "false" },
        other_files_to_push: { "fixtures/data.json" => "/sdcard/data.json" },
        labels: { team: "mobile" }
      )

      expect(args).to include(
        "--additional-test-options=clearPackageData=true",
        "--additional-test-options=coverage=false",
        "--other-files-to-push=fixtures/data.json=/sdcard/data.json",
        "--labels=team=mobile"
      )
    end

    it "protects dictionary values that contain a comma" do
      expect(arguments(labels: { note: "a,b" })).to include("--labels=^|^note=a,b")
    end

    it "emits paths to pull as a list" do
      expect(arguments(paths_to_pull: ["/sdcard/screenshots",
                                       "/sdcard/logs"])).to include("--paths-to-pull=/sdcard/screenshots,/sdcard/logs")
    end
  end

  describe "validation" do
    it "requires at least one device" do
      expect { described_class.new(devices: [], test_apk: "test.apk") }.to raise_error(ArgumentError, /device/)
    end

    it "requires a test apk" do
      expect { described_class.new(devices: ["shiba-34"], test_apk: nil) }.to raise_error(ArgumentError, /test_apk/)
    end

    it "rejects unknown options" do
      expect { described_class.new(**required, bogus: 1) }.to raise_error(ArgumentError)
    end
  end
end
