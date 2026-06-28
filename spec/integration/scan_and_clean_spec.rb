# frozen_string_literal: true

require "stringio"

RSpec.describe "scan and clean integration" do
  before do
    security_fetcher = instance_double(GemXray::SecurityAdvisoryFetcher, fetch: [])
    allow(GemXray::SecurityAdvisoryFetcher).to receive(:new).and_return(security_fetcher)
    deprecated_info = GemXray::DeprecatedGemFetcher::GemDeprecationInfo.new(
      name: "gem",
      version: "1.0.0",
      yanked: false,
      post_install_message: nil,
      readme_deprecated: false,
      readme_url: nil,
      source: :unknown
    )
    deprecated_fetcher = instance_double(GemXray::DeprecatedGemFetcher, fetch: deprecated_info)
    allow(GemXray::DeprecatedGemFetcher).to receive(:new).and_return(deprecated_fetcher)
    unmaintained_analyzer = instance_double(GemXray::Analyzers::UnmaintainedAnalyzer, analyze: [])
    allow(GemXray::Analyzers::UnmaintainedAnalyzer).to receive(:new).and_return(unmaintained_analyzer)
  end

  it "scans a fixture project and applies clean in dry-run mode with previews" do
    with_project(sample_project_files) do |project_dir|
      gemfile_path = File.join(project_dir, "Gemfile")
      scan_out = StringIO.new
      clean_out = StringIO.new

      scan_code = GemXray::CLI.start(
        ["scan", "--format", "json", "--gemfile", gemfile_path],
        out: scan_out,
        err: StringIO.new,
        stdin: StringIO.new
      )
      clean_code = GemXray::CLI.start(
        ["clean", "--auto-fix", "--dry-run", "--gemfile", gemfile_path],
        out: clean_out,
        err: StringIO.new,
        stdin: StringIO.new
      )

      payload = JSON.parse(scan_out.string)

      expect(scan_code).to eq(0)
      expect(clean_code).to eq(0)
      expect(payload.fetch("results").map { |item| item.fetch("gem_name") }).to include("net-imap")
      expect(clean_out.string).to include("@@ Gemfile:")
      expect(File.read(gemfile_path)).to include('gem "net-imap"')
    end
  end
end
