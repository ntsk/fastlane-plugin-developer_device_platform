describe Fastlane::DeveloperDevicePlatform::SessionSummary do
  let(:session) do
    Fastlane::DeveloperDevicePlatform::Session.parse(File.read(File.join(__dir__, "..", "fixtures", "session_failed.json")))
  end
  let(:summary) { described_class.new(session) }

  describe "#rows" do
    it "lists one row per execution, annotated with the message when not passed" do
      expect(summary.rows).to eq([
                                   ["job-000", "execution-000", "PASSED"],
                                   ["job-001", "execution-000", "FAILED: 2 test cases failed, 5 passed."]
                                 ])
    end

    it "falls back to the job itself when it has no executions yet" do
      running = Fastlane::DeveloperDevicePlatform::Session.parse(File.read(File.join(__dir__, "..", "fixtures", "session_running.json")))

      expect(described_class.new(running).rows).to eq([["job-000", "", "Allocating device shiba-34."]])
    end
  end

  describe "#to_s" do
    it "renders a table with the session headline and the console url" do
      text = summary.to_s

      expect(text).to include("Session 3f9c2a1e finished with result FAILED")
      expect(text).to include("1 of 2 jobs failed.")
      expect(text).to include("JOB", "EXECUTION", "RESULT")
      expect(text).to include("job-001", "FAILED: 2 test cases failed, 5 passed.")
      expect(text).to include("https://console.cloud.google.com/storage/browser/my-project-devicerun/automation/sessions/3f9c2a1e/")
    end
  end
end
