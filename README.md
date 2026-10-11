# fastlane-plugin-developer_device_platform

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-developer_device_platform)
[![Test](https://github.com/ntsk/fastlane-plugin-developer_device_platform/actions/workflows/test.yml/badge.svg)](https://github.com/ntsk/fastlane-plugin-developer_device_platform/actions/workflows/test.yml)

Run Android instrumentation tests on [Google Cloud Developer Device Platform](https://docs.cloud.google.com/developer-device-platform) (Device Run) from fastlane.

Firebase Test Lab is [deprecated and shuts down on September 30, 2027](https://firebase.google.com/docs/test-lab/migrate-faq). Developer Device Platform is its successor on Google Cloud. This plugin wraps `gcloud beta device-run` so Android instrumentation tests can keep running from a fastlane lane.

## What the action does

1. Uploads the app and test APKs to Cloud Storage and submits a Device Run session (one job per device).
2. Waits for the session to complete, streaming gcloud's progress to the fastlane log.
3. Reads the full session report, prints a per-job result table and the Cloud Console link.
4. Optionally downloads the artifacts (`junit.xml`, `logcat.txt`, `video.mp4`, ...) to a local directory.
5. Fails the lane unless the session result is `PASSED` (configurable).

## Prerequisites

- [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) 580.0.0 or newer with the `beta` component on the machine running fastlane (`gcloud components update && gcloud components install beta`). On GitHub Actions, pin `version` in `google-github-actions/setup-gcloud`; its default `latest` can resolve to an older release that predates Device Run.
- A Google Cloud project with billing enabled and the APIs turned on:

  ```sh
  gcloud services enable devicerun.googleapis.com devicestreaming.googleapis.com testing.googleapis.com
  ```

- The account running the tests needs `roles/devicerun.admin` and `roles/serviceusage.serviceUsageConsumer` on the project (see the [quickstart](https://docs.cloud.google.com/developer-device-platform/quickstart)).
- Authentication for gcloud. Either log in interactively (`gcloud auth login`) or pass a service account key with `service_account_key_file` (see [Authentication](#authentication)).

## Installation

```sh
fastlane add_plugin developer_device_platform
```

## Usage

```ruby
lane :instrumentation_tests do
  gradle(task: "assembleDebug assembleDebugAndroidTest")

  developer_device_platform(
    project_id: "my-gcp-project",
    devices: ["shiba-34", "tokay-36"],
    apps: ["app/build/outputs/apk/debug/app-debug.apk"],
    test_apk: "app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk",
    orchestrator_version: "auto",
    instrumentation_timeout: "15m",
    video: "on-failure",
    download_dir: "build/device-run"
  )
end
```

Find device IDs with `gcloud beta device-run devices list` (for example `--filter="HARDWARE_TYPE=PHYSICAL AND OS_VERSION=35"`). An ID is `<model>-<api level>`, such as `shiba-34`, or a descriptive name for virtual devices, such as `mediumphone-arm-34`.

Inputs may also be `gs://` URIs, in which case nothing is uploaded:

```ruby
developer_device_platform(
  devices: ["mediumphone-arm-34"],
  apps: ["gs://my-bucket/app-debug.apk"],
  test_apk: "gs://my-bucket/app-debug-androidTest.apk",
  sharding_option: "smart",
  smart_sharding_target_duration: "5m",
  smart_sharding_record_name: "nightly",
  flaky_test_attempts: 2,
  flaky_test_retry_level: "test"
)
```

### Options

Options mirror the flags of `gcloud beta device-run sessions submit instrumentation`. Every option can also be set through the environment variable `DEVELOPER_DEVICE_PLATFORM_<OPTION>`.

| Option | Type | Description |
| --- | --- | --- |
| `devices` | Array | **Required.** Device type IDs. One job is created per device. |
| `test_apk` | String | **Required.** Instrumentation test APK, local path or `gs://` URI. |
| `apps` | Array | App files (`.apk`, `.aab`, `.apks`) installed before the test, in order. |
| `project_id` | String | Google Cloud project. Defaults to the active gcloud configuration. |
| `service_account_key_file` | String | Service account key JSON used to authenticate gcloud for this action only. |
| `gcloud_binary` | String | Path to `gcloud`. Default `gcloud`. |
| `location` | String | Cloud location of the session. Default `global`. |
| `bucket_name` | String | Bucket for inputs and results. Defaults to `PROJECT_ID-devicerun`, created on first use. |
| `test_runner_class` | String | Instrumentation runner class. Defaults to the manifest value. |
| `test_targets` | Array | Targets such as `"class com.example.FooTest"` or `"notPackage com.example.slow"`. |
| `additional_test_options` | Hash | Options passed to the runner, e.g. `{ clearPackageData: "true" }`. |
| `other_files_to_push` | Hash | Files pushed before the test, `{ "local/or/gs/path" => "/sdcard/dest" }`. |
| `paths_to_pull` | Array | Device paths pulled after the test. |
| `instrumentation_timeout` | String | `1m` to `3h`. Default `5m`. |
| `orchestrator_version` | String | Android Test Orchestrator version or `auto`. Unset means no orchestrator. |
| `labels` | Hash | Labels attached to the session. |
| `locale` | String | Device locale, e.g. `ja-JP`. |
| `orientation` | String | `portrait` or `landscape`. |
| `coordinates` | String | Mock GPS location `latitude,longitude`. |
| `video` | String | `always` or `on-failure`. |
| `dumpsys` | String | `always` or `on-failure`. |
| `bugreport` | String | `always` or `on-failure`. |
| `sharding_option` | String | `uniform` or `smart`. |
| `uniform_sharding_count` | Integer | Shard count. Required with `uniform`. |
| `smart_sharding_target_duration` | String | Target duration per shard, `2m` to `1h`. Required with `smart`. |
| `smart_sharding_record_name` | String | Timing record name without extension. Required with `smart`. |
| `smart_sharding_max_shard_count` | Integer | Maximum smart shards. `0` uses the system limit. |
| `flaky_test_attempts` | Integer | Attempts per shard. Default `1`. |
| `flaky_test_parallel_retry` | Boolean | Retry in parallel instead of sequentially. |
| `flaky_test_retry_level` | String | `shard` or `test`. |
| `async` | Boolean | Return the session ID right after submission. Default `false`. |
| `download_dir` | String | Local directory to download the session artifacts into. |
| `fail_on_failure` | Boolean | Fail the lane when the result is not `PASSED`. Default `true`. |

### Return value and lane context

The action returns a `Fastlane::DeveloperDevicePlatform::Session` (or the session ID when `async` is true) and sets:

| Lane context key | Value |
| --- | --- |
| `DEVELOPER_DEVICE_PLATFORM_SESSION_ID` | Session ID |
| `DEVELOPER_DEVICE_PLATFORM_RESULT` | `PASSED`, `FAILED`, `ERROR`, `TIMED_OUT` or `CANCELLED` |
| `DEVELOPER_DEVICE_PLATFORM_OUTPUT_DIRECTORY` | `gs://BUCKET/automation/sessions/SESSION_ID` |
| `DEVELOPER_DEVICE_PLATFORM_CONSOLE_URL` | Cloud Console link to the artifacts |
| `DEVELOPER_DEVICE_PLATFORM_DOWNLOAD_DIR` | Local artifact directory when `download_dir` is set |

```ruby
session = developer_device_platform(devices: ["shiba-34"], test_apk: "test.apk", fail_on_failure: false)
session.jobs.each { |job| puts "#{job.display_name}: #{job.result} #{job.message}" }
```

### Results

Artifacts land in `gs://BUCKET/automation/sessions/SESSION_ID/job-NNN/`: `merged_junit.xml` per job, and `junit.xml`, `instrumentation.log`, `logcat.txt`, `video.mp4` and pulled files per execution. With `download_dir` the same tree is copied to `<download_dir>/<SESSION_ID>/`, so JUnit reporters can pick up `**/merged_junit.xml`.

### Authentication

On CI, the simplest setup is a service account key passed through `service_account_key_file`. The plugin hands it to gcloud via `CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE`, so the global gcloud configuration is left untouched. If your CI already authenticates gcloud (for example with Workload Identity Federation through `google-github-actions/auth`), omit the option and the active credentials are used.

Device Run reads inputs and writes results through its own service agent (`service-PROJECT_NUMBER@gcp-sa-devicerun.iam.gserviceaccount.com`). When you point `bucket_name` at a bucket in another project, grant that agent `roles/storage.objectViewer` on it (see [Share storage](https://docs.cloud.google.com/developer-device-platform/device-run/share-storage)).

## Development

```sh
bundle install
bundle exec rake        # rspec + rubocop
bundle exec fastlane action developer_device_platform
```

The gcloud integration is exercised against a fake `gcloud` executable in `spec/fixtures`, so the test suite needs neither credentials nor network access.

## License

MIT
