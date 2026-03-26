# frozen_string_literal: true

RSpec.describe GemXray::Analyzers::VersionAnalyzer do
  def build_gem_entry(name:, version: nil, groups: [])
    GemXray::GemEntry.new(
      name: name,
      version: version,
      groups: groups,
      line_number: 1
    )
  end

  def build_analyzer(config:, gemfile_parser:, stdgems_client:, rails_knowledge:)
    described_class.new(
      config: config,
      gemfile_parser: gemfile_parser,
      stdgems_client: stdgems_client,
      rails_knowledge: rails_knowledge
    )
  end

  def stub_parser(ruby_version: "3.2.2", rails_version: "7.1.3")
    parser = instance_double(GemXray::GemfileParser)
    allow(parser).to receive(:ruby_version).and_return(ruby_version)
    allow(parser).to receive(:rails_version).and_return(rails_version)
    parser
  end

  def stub_stdgems(default_gems: [], bundled_gems: [])
    client = instance_double(GemXray::StdgemsClient)
    allow(client).to receive(:default_gems_for).and_return(default_gems)
    allow(client).to receive(:bundled_gems_for).and_return(bundled_gems)
    client
  end

  describe "#analyze" do
    it "reports unpinned default gems as version_redundant" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir)
        parser = stub_parser
        stdgems = stub_stdgems(default_gems: %w[json csv])
        knowledge = GemXray::RailsKnowledge.new

        analyzer = build_analyzer(
          config: config,
          gemfile_parser: parser,
          stdgems_client: stdgems,
          rails_knowledge: knowledge
        )

        gems = [build_gem_entry(name: "json")]
        results = analyzer.analyze(gems)

        expect(results.length).to eq(1)
        expect(results.first.reasons.first.type).to eq(:version_redundant)
        expect(results.first.reasons.first.detail).to include("default gem")
      end
    end

    it "does not report pinned default gems" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir)
        parser = stub_parser
        stdgems = stub_stdgems(default_gems: %w[json])
        knowledge = instance_double(GemXray::RailsKnowledge)
        allow(knowledge).to receive(:find_removal).and_return(nil)

        analyzer = build_analyzer(
          config: config,
          gemfile_parser: parser,
          stdgems_client: stdgems,
          rails_knowledge: knowledge
        )

        gems = [build_gem_entry(name: "json", version: "~> 2.7")]
        results = analyzer.analyze(gems)

        # Should not report default gem finding (pinned version)
        default_results = results.select { |r| r.reasons.any? { |reason| reason.detail.include?("default gem") } }
        expect(default_results).to be_empty
      end
    end

    it "reports unpinned bundled gems as version_redundant" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir)
        parser = stub_parser
        stdgems = stub_stdgems(bundled_gems: %w[minitest])
        knowledge = instance_double(GemXray::RailsKnowledge)
        allow(knowledge).to receive(:find_removal).and_return(nil)

        analyzer = build_analyzer(
          config: config,
          gemfile_parser: parser,
          stdgems_client: stdgems,
          rails_knowledge: knowledge
        )

        gems = [build_gem_entry(name: "minitest")]
        results = analyzer.analyze(gems)

        expect(results.length).to eq(1)
        expect(results.first.reasons.first.detail).to include("bundled gem")
      end
    end

    it "reports gems removed in Rails version" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir)
        parser = stub_parser(rails_version: "7.1.0")
        stdgems = stub_stdgems
        knowledge = GemXray::RailsKnowledge.new

        analyzer = build_analyzer(
          config: config,
          gemfile_parser: parser,
          stdgems_client: stdgems,
          rails_knowledge: knowledge
        )

        gems = [build_gem_entry(name: "zeitwerk")]
        results = analyzer.analyze(gems)

        rails_results = results.select { |r| r.reasons.any? { |reason| reason.detail.include?("Rails") } }
        expect(rails_results.length).to eq(1)
        expect(rails_results.first.reasons.first.detail).to include("since Rails 6.0")
      end
    end

    it "does not report Rails changes for older Rails versions" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir)
        parser = stub_parser(rails_version: "5.2.8")
        stdgems = stub_stdgems
        knowledge = GemXray::RailsKnowledge.new

        analyzer = build_analyzer(
          config: config,
          gemfile_parser: parser,
          stdgems_client: stdgems,
          rails_knowledge: knowledge
        )

        gems = [build_gem_entry(name: "zeitwerk")]
        results = analyzer.analyze(gems)

        expect(results).to be_empty
      end
    end

    it "skips whitelisted gems" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, whitelist: ["json"])
        parser = stub_parser
        stdgems = stub_stdgems(default_gems: %w[json])
        knowledge = instance_double(GemXray::RailsKnowledge)

        analyzer = build_analyzer(
          config: config,
          gemfile_parser: parser,
          stdgems_client: stdgems,
          rails_knowledge: knowledge
        )

        gems = [build_gem_entry(name: "json")]
        results = analyzer.analyze(gems)

        expect(results).to be_empty
      end
    end

    it "sets warning severity for all findings" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir)
        parser = stub_parser
        stdgems = stub_stdgems(default_gems: %w[json])
        knowledge = GemXray::RailsKnowledge.new

        analyzer = build_analyzer(
          config: config,
          gemfile_parser: parser,
          stdgems_client: stdgems,
          rails_knowledge: knowledge
        )

        gems = [build_gem_entry(name: "json")]
        results = analyzer.analyze(gems)

        expect(results.first.severity).to eq(:warning)
      end
    end
  end
end
