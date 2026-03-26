# frozen_string_literal: true

RSpec.describe GemXray::Analyzers::UnusedAnalyzer do
  def build_gem_entry(name:, groups: [], version: nil, autorequire: nil)
    GemXray::GemEntry.new(
      name: name,
      version: version,
      groups: groups,
      line_number: 1,
      autorequire: autorequire
    )
  end

  def build_snapshot(requires: Set.new, constants: Set.new, dependency_names: Set.new)
    GemXray::CodeScanner::Snapshot.new(
      requires: requires,
      constants: constants,
      dependency_names: dependency_names,
      files: []
    )
  end

  def build_analyzer(config:, snapshot:)
    parser = instance_double(GemXray::GemfileParser)
    described_class.new(
      config: config,
      gemfile_parser: parser,
      code_snapshot: snapshot,
      gem_metadata_resolver: GemXray::GemMetadataResolver.new
    )
  end

  describe "#analyze" do
    it "reports gems not found in code as unused" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir)
        snapshot = build_snapshot
        analyzer = build_analyzer(config: config, snapshot: snapshot)

        gems = [build_gem_entry(name: "awesome_print")]
        results = analyzer.analyze(gems)

        expect(results.length).to eq(1)
        expect(results.first.gem_name).to eq("awesome_print")
        expect(results.first.reasons.first.type).to eq(:unused)
      end
    end

    it "does not report gems that are required in code" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir)
        snapshot = build_snapshot(requires: Set.new(["awesome_print"]))
        analyzer = build_analyzer(config: config, snapshot: snapshot)

        gems = [build_gem_entry(name: "awesome_print")]
        results = analyzer.analyze(gems)

        expect(results).to be_empty
      end
    end

    it "does not report gems referenced by constant" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir)
        snapshot = build_snapshot(constants: Set.new(["AwesomePrint"]))
        analyzer = build_analyzer(config: config, snapshot: snapshot)

        gems = [build_gem_entry(name: "awesome_print")]
        results = analyzer.analyze(gems)

        expect(results).to be_empty
      end
    end

    it "does not report gems listed as gemspec dependencies" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir)
        snapshot = build_snapshot(dependency_names: Set.new(["some_gem"]))
        analyzer = build_analyzer(config: config, snapshot: snapshot)

        gems = [build_gem_entry(name: "some_gem")]
        results = analyzer.analyze(gems)

        expect(results).to be_empty
      end
    end

    it "skips whitelisted gems" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, whitelist: ["bootsnap"])
        snapshot = build_snapshot
        analyzer = build_analyzer(config: config, snapshot: snapshot)

        gems = [build_gem_entry(name: "bootsnap")]
        results = analyzer.analyze(gems)

        expect(results).to be_empty
      end
    end

    it "skips known dev tools" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir)
        snapshot = build_snapshot
        analyzer = build_analyzer(config: config, snapshot: snapshot)

        gems = [
          build_gem_entry(name: "rubocop", groups: [:development]),
          build_gem_entry(name: "rspec", groups: [:test]),
          build_gem_entry(name: "rake")
        ]
        results = analyzer.analyze(gems)

        expect(results).to be_empty
      end
    end

    it "reports development group gems with warning severity" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir)
        snapshot = build_snapshot
        analyzer = build_analyzer(config: config, snapshot: snapshot)

        gems = [build_gem_entry(name: "awesome_print", groups: [:development])]
        results = analyzer.analyze(gems)

        expect(results.first.severity).to eq(:warning)
        expect(results.first.reasons.first.detail).to include("group :development")
      end
    end

    it "reports production gems with danger severity" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir)
        snapshot = build_snapshot
        analyzer = build_analyzer(config: config, snapshot: snapshot)

        gems = [build_gem_entry(name: "unused_prod_gem")]
        results = analyzer.analyze(gems)

        expect(results.first.severity).to eq(:danger)
        expect(results.first.reasons.first.detail).to include("no require or constant reference")
      end
    end

    it "detects gems used via sub-path require" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir)
        snapshot = build_snapshot(requires: Set.new(["my_gem/utils"]))
        analyzer = build_analyzer(config: config, snapshot: snapshot)

        gems = [build_gem_entry(name: "my_gem")]
        results = analyzer.analyze(gems)

        expect(results).to be_empty
      end
    end

    it "skips autoloaded gems" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir)
        snapshot = build_snapshot
        analyzer = build_analyzer(config: config, snapshot: snapshot)

        gems = [build_gem_entry(name: "devise")]
        results = analyzer.analyze(gems)

        expect(results).to be_empty
      end
    end

    it "skips gems with ignored override" do
      with_project("Gemfile" => 'source "https://rubygems.org"') do |dir|
        config = build_config(dir, overrides: { puma: { severity: "ignore" } })
        snapshot = build_snapshot
        analyzer = build_analyzer(config: config, snapshot: snapshot)

        gems = [build_gem_entry(name: "puma")]
        results = analyzer.analyze(gems)

        expect(results).to be_empty
      end
    end
  end
end
