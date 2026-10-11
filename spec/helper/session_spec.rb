describe Fastlane::DeveloperDevicePlatform::Session do
  let(:failed) { described_class.parse(File.read(File.join(__dir__, "..", "fixtures", "session_failed.json"))) }
  let(:running) { described_class.parse(File.read(File.join(__dir__, "..", "fixtures", "session_running.json"))) }

  it "exposes identity" do
    expect(failed.name).to eq("projects/my-project/locations/global/sessions/3f9c2a1e")
    expect(failed.id).to eq("3f9c2a1e")
  end

  it "exposes lifecycle status" do
    expect(failed.status).to eq("DONE")
    expect(failed).to be_done
    expect(running.status).to eq("RUNNING")
    expect(running).not_to be_done
  end

  it "exposes the overall result" do
    expect(failed.result).to eq("FAILED")
    expect(failed).not_to be_passed
    expect(failed.result_message).to eq("1 of 2 jobs failed.")
    expect(running.result).to be_nil
    expect(running.result_message).to be_nil
  end

  it "derives the output directory and console url from the session config" do
    expect(failed.output_directory).to eq("gs://my-project-devicerun/automation/sessions/3f9c2a1e")
    expect(failed.console_url).to eq("https://console.cloud.google.com/storage/browser/my-project-devicerun/automation/sessions/3f9c2a1e/")
  end

  it "normalizes a trailing slash in the configured output directory" do
    expect(running.output_directory).to eq("gs://my-project-devicerun/automation/sessions/3f9c2a1e")
  end

  describe "#jobs" do
    it "maps job reports with their executions" do
      expect(failed.jobs.map(&:display_name)).to eq(["job-000", "job-001"])

      passed_job, failed_job = failed.jobs
      expect(passed_job.result).to eq("PASSED")
      expect(passed_job).to be_passed
      expect(passed_job.executions.map(&:display_name)).to eq(["execution-000"])
      expect(passed_job.executions.first.result).to eq("PASSED")

      expect(failed_job.result).to eq("FAILED")
      expect(failed_job).not_to be_passed
      expect(failed_job.message).to eq("2 test cases failed, 5 passed.")
      expect(failed_job.executions.first.message).to eq("2 test cases failed, 5 passed.")
    end

    it "falls back to the latest progress message when no cause is reported" do
      job = running.jobs.first
      expect(job.result).to be_nil
      expect(job.message).to eq("Allocating device shiba-34.")
      expect(job.executions).to be_empty
    end

    it "collects output files across jobs and executions" do
      expect(failed.output_files).to contain_exactly(
        "gs://my-project-devicerun/automation/sessions/3f9c2a1e/job-000/merged_junit.xml",
        "gs://my-project-devicerun/automation/sessions/3f9c2a1e/job-000/execution-000/junit.xml",
        "gs://my-project-devicerun/automation/sessions/3f9c2a1e/job-000/execution-000/logcat.txt"
      )
    end
  end

  it "tolerates a session without a report" do
    session = described_class.new({ "name" => "projects/p/locations/global/sessions/x" })

    expect(session.id).to eq("x")
    expect(session).not_to be_done
    expect(session.result).to be_nil
    expect(session.jobs).to be_empty
    expect(session.output_directory).to be_nil
    expect(session.console_url).to be_nil
  end

  it "raises a descriptive error for malformed json" do
    expect { described_class.parse("not json") }.to raise_error(Fastlane::DeveloperDevicePlatform::Session::ParseError)
  end
end
