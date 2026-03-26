# frozen_string_literal: true

RSpec.describe GemXray::Scanner do
  describe "#run" do
    it "returns a Report with detected issues" do
      with_project(sample_project_files) do |dir|
        config = build_config(dir)
        report = described_class.new(config).run

        expect(report).to be_a(GemXray::Report)
        expect(report.results).to be_an(Array)
        expect(report.ruby_version).to be_a(String)
        expect(report.version).to eq(GemXray::VERSION)
        expect(report.scanned_at).to be_a(String)
      end
    end

    it "detects redundant gems in sample project" do
      with_project(sample_project_files) do |dir|
        config = build_config(dir, only: ["redundant"])
        report = described_class.new(config).run

        gem_names = report.results.map(&:gem_name)
        expect(gem_names).to include("net-imap")
      end
    end

    it "respects the only filter" do
      with_project(sample_project_files) do |dir|
        config = build_config(dir, only: ["unused"])
        report = described_class.new(config).run

        types = report.results.flat_map(&:reason_types).uniq
        expect(types).to all(eq(:unused))
      end
    end

    it "applies severity threshold filtering" do
      with_project(sample_project_files) do |dir|
        config = build_config(dir, severity: "danger")
        report = described_class.new(config).run

        severities = report.results.map(&:severity).uniq
        expect(severities).to all(eq(:danger))
      end
    end

    it "applies severity overrides from config" do
      with_project(sample_project_files) do |dir|
        config = build_config(dir, overrides: { "net-imap": { severity: "danger" } })
        report = described_class.new(config).run

        net_imap = report.results.find { |r| r.gem_name == "net-imap" }
        expect(net_imap.severity).to eq(:danger) if net_imap
      end
    end

    it "merges results for the same gem from multiple analyzers" do
      with_project(sample_project_files) do |dir|
        config = build_config(dir)
        report = described_class.new(config).run

        gem_names = report.results.map(&:gem_name)
        expect(gem_names).to eq(gem_names.uniq)
      end
    end

    it "sorts results by severity then gem name" do
      with_project(sample_project_files) do |dir|
        config = build_config(dir)
        report = described_class.new(config).run

        severities = report.results.map(&:severity_order)
        expect(severities).to eq(severities.sort)

        report.results.chunk(&:severity_order).each do |_order, group|
          names = group.map(&:gem_name)
          expect(names).to eq(names.sort)
        end
      end
    end

    it "returns empty results for a minimal project with no issues" do
      with_project(
        "Gemfile" => <<~RUBY,
          source "https://rubygems.org"

          gem "rails", "~> 7.1"
        RUBY
        "Gemfile.lock" => <<~LOCK,
          GEM
            remote: https://rubygems.org/
            specs:
              rails (7.1.3)

          PLATFORMS
            ruby

          DEPENDENCIES
            rails (~> 7.1)

          RUBY VERSION
             ruby 3.2.2p53

          BUNDLED WITH
             2.5.10
        LOCK
        "config/application.rb" => 'require "rails"'
      ) do |dir|
        config = build_config(dir, only: ["redundant"])
        report = described_class.new(config).run

        expect(report.results).to be_empty
      end
    end
  end
end
