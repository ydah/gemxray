# frozen_string_literal: true

RSpec.describe GemXray::Analyzers::SecurityAnalyzer do
  def advisory_db_files(gem_name:, cve: "2020-8161", patched_versions: [">= 2.0.9"], unaffected_versions: [])
    {
      "advisory-db/gems/#{gem_name}/#{cve}.yml" => <<~YAML
        ---
        gem: #{gem_name}
        cve: #{cve}
        title: Vulnerable #{gem_name}
        url: https://example.test/#{cve}
        patched_versions:
        #{patched_versions.map { |version| "  - \"#{version}\"" }.join("\n")}
        unaffected_versions:
        #{unaffected_versions.map { |version| "  - \"#{version}\"" }.join("\n")}
      YAML
    }
  end

  def build_security_analyzer(project_dir, **options)
    parser = GemXray::GemfileParser.new(File.join(project_dir, "Gemfile"))
    config_options = {
      only: ["security"],
      security: {
        enabled: true,
        advisory_db_path: File.join(project_dir, "advisory-db"),
        cache_ttl: 0
      }
    }.merge(options)
    config = build_config(project_dir, **config_options)
    [described_class.new(config: config, gemfile_parser: parser), parser]
  end

  it "reports vulnerable direct dependencies using the locked version" do
    with_project(
      {
        "Gemfile" => <<~RUBY,
          source "https://rubygems.org"

          gem "rack", "~> 2.0"
        RUBY
        "Gemfile.lock" => <<~LOCK
          GEM
            remote: https://rubygems.org/
            specs:
              rack (2.0.8)

          PLATFORMS
            ruby

          DEPENDENCIES
            rack (~> 2.0)

          BUNDLED WITH
             2.5.10
        LOCK
      }.merge(advisory_db_files(gem_name: "rack"))
    ) do |project_dir|
      analyzer, parser = build_security_analyzer(project_dir)

      results = analyzer.analyze(parser.parse)

      expect(results.length).to eq(1)
      expect(results.first.gem_name).to eq("rack")
      expect(results.first.gemfile_line).to eq(3)
      expect(results.first.severity).to eq(:danger)
      expect(results.first.reasons.first.type).to eq(:security_vulnerability)
      expect(results.first.reasons.first.detail).to include("rack 2.0.8 is affected by CVE-2020-8161")
      expect(results.first.suggestion).to include("Update rack")
    end
  end

  it "reports vulnerable transitive dependencies from Gemfile.lock" do
    with_project(
      {
        "Gemfile" => <<~RUBY,
          source "https://rubygems.org"

          gem "parent_gem"
        RUBY
        "Gemfile.lock" => <<~LOCK
          GEM
            remote: https://rubygems.org/
            specs:
              parent_gem (1.0.0)
                vulnerable_dep
              vulnerable_dep (0.9.0)

          PLATFORMS
            ruby

          DEPENDENCIES
            parent_gem

          BUNDLED WITH
             2.5.10
        LOCK
      }.merge(advisory_db_files(gem_name: "vulnerable_dep", cve: "2024-0001", patched_versions: [">= 1.0.0"]))
    ) do |project_dir|
      analyzer, parser = build_security_analyzer(project_dir)

      results = analyzer.analyze(parser.parse)

      expect(results.map(&:gem_name)).to include("vulnerable_dep")
      result = results.find { |item| item.gem_name == "vulnerable_dep" }
      expect(result.gemfile_line).to be_nil
      expect(result.reasons.first.detail).to include("vulnerable_dep 0.9.0")
    end
  end

  it "does not report patched versions" do
    with_project(
      {
        "Gemfile" => <<~RUBY,
          source "https://rubygems.org"

          gem "rack", "~> 2.0"
        RUBY
        "Gemfile.lock" => <<~LOCK
          GEM
            remote: https://rubygems.org/
            specs:
              rack (2.0.9)

          PLATFORMS
            ruby

          DEPENDENCIES
            rack (~> 2.0)

          BUNDLED WITH
             2.5.10
        LOCK
      }.merge(advisory_db_files(gem_name: "rack"))
    ) do |project_dir|
      analyzer, parser = build_security_analyzer(project_dir)

      expect(analyzer.analyze(parser.parse)).to be_empty
    end
  end

  it "skips whitelisted gems" do
    with_project(
      {
        "Gemfile" => <<~RUBY,
          source "https://rubygems.org"

          gem "rack", "~> 2.0"
        RUBY
        "Gemfile.lock" => <<~LOCK
          GEM
            remote: https://rubygems.org/
            specs:
              rack (2.0.8)

          PLATFORMS
            ruby

          DEPENDENCIES
            rack (~> 2.0)

          BUNDLED WITH
             2.5.10
        LOCK
      }.merge(advisory_db_files(gem_name: "rack"))
    ) do |project_dir|
      analyzer, parser = build_security_analyzer(project_dir, whitelist: ["rack"])

      expect(analyzer.analyze(parser.parse)).to be_empty
    end
  end
end
