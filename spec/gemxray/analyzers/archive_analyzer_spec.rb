# frozen_string_literal: true

RSpec.describe GemXray::Analyzers::ArchiveAnalyzer do
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

  def stub_checker(archived:, error: nil)
    checker = instance_double(GemXray::ArchiveChecker)
    result = GemXray::ArchiveChecker::ArchiveResult.new(owner_repo: "owner/repo", archived: archived, error: error)
    allow(GemXray::ArchiveChecker).to receive(:new).and_return(checker)
    allow(checker).to receive(:check).and_return(result)
    checker
  end

  def build_analyzer(config:)
    parser = instance_double(GemXray::GemfileParser)
    described_class.new(config: config, gemfile_parser: parser)
  end

  describe "#analyze" do
    it "reports archived repositories" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, archive: { enabled: true, github_token_env: "GITHUB_TOKEN" })
        stub_finder("owner/archived-repo")
        stub_checker(archived: true)
        analyzer = build_analyzer(config: config)

        gems = [build_gem_entry(name: "archived_gem")]
        results = analyzer.analyze(gems)

        expect(results.length).to eq(1)
        expect(results.first.reasons.first.type).to eq(:archived)
        expect(results.first.severity).to eq(:warning)
        expect(results.first.reasons.first.detail).to include("archived")
      end
    end

    it "does not report active repositories" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, archive: { enabled: true, github_token_env: "GITHUB_TOKEN" })
        stub_finder("owner/active-repo")
        stub_checker(archived: false)
        analyzer = build_analyzer(config: config)

        gems = [build_gem_entry(name: "active_gem")]
        results = analyzer.analyze(gems)

        expect(results).to be_empty
      end
    end

    it "skips gems without GitHub repositories" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, archive: { enabled: true, github_token_env: "GITHUB_TOKEN" })
        stub_finder(nil)
        analyzer = build_analyzer(config: config)

        gems = [build_gem_entry(name: "no_repo_gem")]
        results = analyzer.analyze(gems)

        expect(results).to be_empty
      end
    end

    it "skips whitelisted gems" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, whitelist: ["skip_me"], archive: { enabled: true, github_token_env: "GITHUB_TOKEN" })
        stub_finder("owner/repo")
        stub_checker(archived: true)
        analyzer = build_analyzer(config: config)

        gems = [build_gem_entry(name: "skip_me")]
        results = analyzer.analyze(gems)

        expect(results).to be_empty
      end
    end

    it "skips gems with checker errors" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, archive: { enabled: true, github_token_env: "GITHUB_TOKEN" })
        stub_finder("owner/repo")
        stub_checker(archived: nil, error: "rate limit exceeded")
        analyzer = build_analyzer(config: config)

        gems = [build_gem_entry(name: "error_gem")]
        results = analyzer.analyze(gems)

        expect(results).to be_empty
      end
    end
  end
end
