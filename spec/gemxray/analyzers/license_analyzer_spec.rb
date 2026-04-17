# frozen_string_literal: true

RSpec.describe GemXray::Analyzers::LicenseAnalyzer do
  def build_gem_entry(name:, version: nil, groups: [])
    GemXray::GemEntry.new(
      name: name,
      version: version,
      groups: groups,
      line_number: 1
    )
  end

  def build_analyzer(config:, fetcher: nil, matcher: nil)
    parser = instance_double(GemXray::GemfileParser)
    described_class.new(config: config, gemfile_parser: parser)
  end

  def stub_fetcher(licenses:, source: :local)
    fetcher = instance_double(GemXray::LicenseFetcher)
    info = GemXray::LicenseFetcher::GemLicenseInfo.new(
      name: "gem", version: "1.0", licenses: licenses, source: source, homepage: nil
    )
    allow(GemXray::LicenseFetcher).to receive(:new).and_return(fetcher)
    allow(fetcher).to receive(:fetch).and_return(info)
    fetcher
  end

  describe "#analyze" do
    it "reports license violations when not in allowed list" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, license: { enabled: true, allowed: ["MIT"], deny_unknown: false })
        stub_fetcher(licenses: ["GPL-3.0"])
        analyzer = build_analyzer(config: config)

        gems = [build_gem_entry(name: "gpl_gem")]
        results = analyzer.analyze(gems)

        expect(results.length).to eq(1)
        expect(results.first.reasons.first.type).to eq(:license_violation)
        expect(results.first.severity).to eq(:danger)
        expect(results.first.reasons.first.detail).to include("GPL-3.0")
      end
    end

    it "does not report gems with allowed licenses" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, license: { enabled: true, allowed: ["MIT"], deny_unknown: false })
        stub_fetcher(licenses: ["MIT"])
        analyzer = build_analyzer(config: config)

        gems = [build_gem_entry(name: "mit_gem")]
        results = analyzer.analyze(gems)

        expect(results).to be_empty
      end
    end

    it "reports unknown licenses as warning by default" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, license: { enabled: true, allowed: ["MIT"], deny_unknown: false })
        stub_fetcher(licenses: [])
        analyzer = build_analyzer(config: config)

        gems = [build_gem_entry(name: "no_license_gem")]
        results = analyzer.analyze(gems)

        expect(results.length).to eq(1)
        expect(results.first.reasons.first.type).to eq(:license_unknown)
        expect(results.first.severity).to eq(:warning)
      end
    end

    it "reports unknown licenses as danger when deny_unknown is true" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, license: { enabled: true, allowed: ["MIT"], deny_unknown: true })
        stub_fetcher(licenses: [])
        analyzer = build_analyzer(config: config)

        gems = [build_gem_entry(name: "no_license_gem")]
        results = analyzer.analyze(gems)

        expect(results.first.severity).to eq(:danger)
      end
    end

    it "skips analysis when no allowed list is configured and license is present" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, license: { enabled: true, allowed: [], deny_unknown: false })
        stub_fetcher(licenses: ["GPL-3.0"])
        analyzer = build_analyzer(config: config)

        gems = [build_gem_entry(name: "any_gem")]
        results = analyzer.analyze(gems)

        expect(results).to be_empty
      end
    end

    it "skips whitelisted gems" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, whitelist: ["skip_me"], license: { enabled: true, allowed: ["MIT"], deny_unknown: false })
        stub_fetcher(licenses: ["GPL-3.0"])
        analyzer = build_analyzer(config: config)

        gems = [build_gem_entry(name: "skip_me")]
        results = analyzer.analyze(gems)

        expect(results).to be_empty
      end
    end
  end
end
