# frozen_string_literal: true

RSpec.describe GemXray::Analyzers::DeprecatedAnalyzer do
  def build_gem_entry(name:, version: nil, groups: [])
    GemXray::GemEntry.new(
      name: name,
      version: version,
      groups: groups,
      line_number: 3
    )
  end

  def deprecation_info(name:, version: "1.0.0", yanked: false, post_install_message: nil,
                       readme_deprecated: false, readme_url: nil)
    GemXray::DeprecatedGemFetcher::GemDeprecationInfo.new(
      name: name,
      version: version,
      yanked: yanked,
      post_install_message: post_install_message,
      readme_deprecated: readme_deprecated,
      readme_url: readme_url,
      source: :rubygems_version
    )
  end

  def stub_fetcher(info)
    fetcher = instance_double(GemXray::DeprecatedGemFetcher)
    allow(GemXray::DeprecatedGemFetcher).to receive(:new).and_return(fetcher)
    allow(fetcher).to receive(:fetch).and_return(info)
    fetcher
  end

  def build_analyzer(config:)
    parser = instance_double(GemXray::GemfileParser)
    allow(parser).to receive(:resolved_version).and_return(Gem::Version.new("1.0.0"))
    described_class.new(config: config, gemfile_parser: parser)
  end

  describe "#analyze" do
    it "reports yanked gems as danger" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, deprecated: { enabled: true, check_readme: true })
        stub_fetcher(deprecation_info(name: "old_gem", yanked: true))
        analyzer = build_analyzer(config: config)

        results = analyzer.analyze([build_gem_entry(name: "old_gem")])

        expect(results.length).to eq(1)
        expect(results.first.severity).to eq(:danger)
        expect(results.first.reasons.first.type).to eq(:deprecated_yanked)
        expect(results.first.reasons.first.detail).to include("has been yanked")
      end
    end

    it "reports deprecated post_install_message as warning" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, deprecated: { enabled: true, check_readme: true })
        stub_fetcher(
          deprecation_info(
            name: "old_gem",
            post_install_message: "This gem is deprecated. Use new_gem instead."
          )
        )
        analyzer = build_analyzer(config: config)

        results = analyzer.analyze([build_gem_entry(name: "old_gem")])

        expect(results.length).to eq(1)
        expect(results.first.severity).to eq(:warning)
        expect(results.first.reasons.first.type).to eq(:deprecated_post_install_message)
      end
    end

    it "reports README deprecation as warning" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, deprecated: { enabled: true, check_readme: true })
        stub_fetcher(
          deprecation_info(
            name: "readme_gem",
            readme_deprecated: true,
            readme_url: "https://raw.githubusercontent.com/example/readme_gem/HEAD/README.md"
          )
        )
        analyzer = build_analyzer(config: config)

        results = analyzer.analyze([build_gem_entry(name: "readme_gem")])

        expect(results.length).to eq(1)
        expect(results.first.severity).to eq(:warning)
        expect(results.first.reasons.first.type).to eq(:deprecated_readme)
        expect(results.first.reasons.first.detail).to include("README")
      end
    end

    it "does not report active gems" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, deprecated: { enabled: true, check_readme: true })
        stub_fetcher(deprecation_info(name: "active_gem"))
        analyzer = build_analyzer(config: config)

        results = analyzer.analyze([build_gem_entry(name: "active_gem")])

        expect(results).to be_empty
      end
    end

    it "skips whitelisted gems" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(
          dir,
          whitelist: ["skip_me"],
          deprecated: { enabled: true, check_readme: true }
        )
        stub_fetcher(deprecation_info(name: "skip_me", yanked: true))
        analyzer = build_analyzer(config: config)

        results = analyzer.analyze([build_gem_entry(name: "skip_me")])

        expect(results).to be_empty
      end
    end
  end
end
