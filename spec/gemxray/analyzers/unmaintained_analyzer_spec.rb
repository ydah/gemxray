# frozen_string_literal: true

RSpec.describe GemXray::Analyzers::UnmaintainedAnalyzer do
  def build_gem_entry(name:, version: nil, groups: [])
    GemXray::GemEntry.new(
      name: name,
      version: version,
      groups: groups,
      line_number: 1
    )
  end

  def stub_finder(owner_repo)
    finder = instance_double(GemXray::RepositoryFinder)
    allow(GemXray::RepositoryFinder).to receive(:new).and_return(finder)
    allow(finder).to receive(:find).and_return(owner_repo)
    finder
  end

  def stub_checker(pushed_at:, latest_release_at: nil, error: nil)
    checker = instance_double(GemXray::UnmaintainedChecker)
    result = GemXray::UnmaintainedChecker::ActivityResult.new(
      owner_repo: "owner/repo",
      pushed_at: pushed_at,
      latest_release_at: latest_release_at,
      error: error
    )
    allow(GemXray::UnmaintainedChecker).to receive(:new).and_return(checker)
    allow(checker).to receive(:check).and_return(result)
    checker
  end

  def build_analyzer(config:)
    parser = instance_double(GemXray::GemfileParser)
    described_class.new(config: config, gemfile_parser: parser)
  end

  around do |example|
    original_tz = ENV["TZ"]
    ENV["TZ"] = "UTC"
    example.run
  ensure
    ENV["TZ"] = original_tz
  end

  describe "#analyze" do
    it "reports repositories without recent commits or releases" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, unmaintained: { enabled: true, threshold_days: 730, github_token_env: "GITHUB_TOKEN" })
        stub_finder("owner/stale-repo")
        stub_checker(pushed_at: "2020-01-01T00:00:00Z", latest_release_at: "2021-01-01T00:00:00Z")
        analyzer = build_analyzer(config: config)

        results = analyzer.analyze([build_gem_entry(name: "stale_gem")])

        expect(results.length).to eq(1)
        expect(results.first.reasons.first.type).to eq(:unmaintained)
        expect(results.first.severity).to eq(:warning)
        expect(results.first.reasons.first.detail).to include("last activity was 2021-01-01")
      end
    end

    it "does not report repositories with recent releases" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, unmaintained: { enabled: true, threshold_days: 730, github_token_env: "GITHUB_TOKEN" })
        stub_finder("owner/active-repo")
        stub_checker(pushed_at: "2020-01-01T00:00:00Z", latest_release_at: Time.now.iso8601)
        analyzer = build_analyzer(config: config)

        results = analyzer.analyze([build_gem_entry(name: "active_gem")])

        expect(results).to be_empty
      end
    end

    it "skips gems without GitHub repositories" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, unmaintained: { enabled: true, threshold_days: 730, github_token_env: "GITHUB_TOKEN" })
        stub_finder(nil)
        analyzer = build_analyzer(config: config)

        results = analyzer.analyze([build_gem_entry(name: "no_repo_gem")])

        expect(results).to be_empty
      end
    end

    it "skips checker errors" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, unmaintained: { enabled: true, threshold_days: 730, github_token_env: "GITHUB_TOKEN" })
        stub_finder("owner/repo")
        stub_checker(pushed_at: nil, error: "rate limit exceeded")
        analyzer = build_analyzer(config: config)

        results = analyzer.analyze([build_gem_entry(name: "error_gem")])

        expect(results).to be_empty
      end
    end

    it "skips whitelisted gems" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(
          dir,
          whitelist: ["skip_me"],
          unmaintained: { enabled: true, threshold_days: 730, github_token_env: "GITHUB_TOKEN" }
        )
        stub_finder("owner/repo")
        stub_checker(pushed_at: "2020-01-01T00:00:00Z")
        analyzer = build_analyzer(config: config)

        results = analyzer.analyze([build_gem_entry(name: "skip_me")])

        expect(results).to be_empty
      end
    end
  end
end
