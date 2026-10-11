describe Fastlane::DeveloperDevicePlatform::Options do
  let(:options) { described_class.all.to_h { |item| [item.key, item] } }

  it "reads scalar and array options from DEVELOPER_DEVICE_PLATFORM_* environment variables" do
    expect(options[:project_id].env_name).to eq("DEVELOPER_DEVICE_PLATFORM_PROJECT_ID")
    expect(options[:devices].env_name).to eq("DEVELOPER_DEVICE_PLATFORM_DEVICES")
    expect(options[:async].env_name).to eq("DEVELOPER_DEVICE_PLATFORM_ASYNC")
  end

  it "does not offer environment variables for hash options, which fastlane cannot parse from a string" do
    hash_options = described_class.all.select { |item| item.data_type == Hash }

    expect(hash_options.map(&:key)).to contain_exactly(:additional_test_options, :other_files_to_push, :labels)
    expect(hash_options.map(&:env_name)).to all(be_nil)
  end

  it "splits array options given through the environment on commas" do
    expect(options[:devices].auto_convert_value("shiba-34,tokay-36")).to eq(["shiba-34", "tokay-36"])
  end
end
