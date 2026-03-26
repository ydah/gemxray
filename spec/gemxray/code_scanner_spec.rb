# frozen_string_literal: true

RSpec.describe GemXray::CodeScanner do
  describe "#scan" do
    it "extracts require statements from Ruby files" do
      with_project(
        "Gemfile" => 'source "https://rubygems.org"',
        "app/models/user.rb" => <<~RUBY
          require "json"
          require 'yaml'
          require("csv")
        RUBY
      ) do |dir|
        config = build_config(dir)
        snapshot = described_class.new(config).scan

        expect(snapshot.requires).to include("json", "yaml", "csv")
      end
    end

    it "extracts require_relative statements" do
      with_project(
        "Gemfile" => 'source "https://rubygems.org"',
        "lib/foo.rb" => 'require_relative "bar"'
      ) do |dir|
        config = build_config(dir)
        snapshot = described_class.new(config).scan

        expect(snapshot.requires).to include("bar")
      end
    end

    it "extracts send(:require, ...) patterns" do
      with_project(
        "Gemfile" => 'source "https://rubygems.org"',
        "lib/foo.rb" => 'send(:require, "dynamic_gem")'
      ) do |dir|
        config = build_config(dir)
        snapshot = described_class.new(config).scan

        expect(snapshot.requires).to include("dynamic_gem")
      end
    end

    it "extracts constants from Ruby files" do
      with_project(
        "Gemfile" => 'source "https://rubygems.org"',
        "app/services/worker.rb" => <<~RUBY
          Sidekiq::Worker
          ActiveRecord::Base
          JSON
        RUBY
      ) do |dir|
        config = build_config(dir)
        snapshot = described_class.new(config).scan

        expect(snapshot.constants).to include("Sidekiq::Worker", "ActiveRecord::Base", "JSON")
      end
    end

    it "extracts gemspec dependency names" do
      with_project(
        "Gemfile" => 'source "https://rubygems.org"',
        "foo.gemspec" => <<~RUBY
          Gem::Specification.new do |spec|
            spec.add_runtime_dependency "bar"
            spec.add_dependency "baz"
          end
        RUBY
      ) do |dir|
        config = build_config(dir)
        snapshot = described_class.new(config).scan

        expect(snapshot.dependency_names).to include("bar", "baz")
      end
    end

    it "scans files with various extensions" do
      with_project(
        "Gemfile" => 'source "https://rubygems.org"',
        "app/views/index.erb" => '<%= require "erb_gem" %>',
        "lib/tasks/deploy.rake" => 'require "rake_gem"'
      ) do |dir|
        config = build_config(dir)
        snapshot = described_class.new(config).scan

        expect(snapshot.requires).to include("erb_gem", "rake_gem")
      end
    end

    it "includes Gemfile and Rakefile in scanned files" do
      with_project(
        "Gemfile" => 'source "https://rubygems.org"',
        "Rakefile" => 'require "bundler/gem_tasks"'
      ) do |dir|
        config = build_config(dir)
        snapshot = described_class.new(config).scan

        expect(snapshot.files.map { |f| File.basename(f) }).to include("Gemfile", "Rakefile")
      end
    end

    it "skips non-scannable file extensions" do
      with_project(
        "Gemfile" => 'source "https://rubygems.org"',
        "app/assets/image.png" => "binary content"
      ) do |dir|
        config = build_config(dir)
        snapshot = described_class.new(config).scan

        png_files = snapshot.files.select { |f| f.end_with?(".png") }
        expect(png_files).to be_empty
      end
    end

    it "skips directories that do not exist" do
      with_project(
        "Gemfile" => 'source "https://rubygems.org"'
      ) do |dir|
        config = build_config(dir)

        expect { described_class.new(config).scan }.not_to raise_error
      end
    end
  end

  describe GemXray::CodeScanner::Snapshot do
    let(:snapshot) do
      described_class.new(
        requires: Set.new(["json", "yaml", "json/parser"]),
        constants: Set.new(["JSON", "YAML", "ActiveRecord"]),
        dependency_names: Set.new(["rake"]),
        files: ["/tmp/foo.rb"]
      )
    end

    describe "#require_used?" do
      it "returns true for exact match" do
        expect(snapshot.require_used?("json")).to be true
      end

      it "returns true for prefix match (subpath)" do
        expect(snapshot.require_used?("json")).to be true
      end

      it "returns false for non-matching candidate" do
        expect(snapshot.require_used?("csv")).to be false
      end

      it "accepts array of candidates" do
        expect(snapshot.require_used?(["csv", "json"])).to be true
      end
    end

    describe "#constant_used?" do
      it "returns true when constant is in set" do
        expect(snapshot.constant_used?(Set.new(["JSON"]))).to be true
      end

      it "returns false when constant is not in set" do
        expect(snapshot.constant_used?(Set.new(["Sidekiq"]))).to be false
      end
    end

    describe "#dependency_used?" do
      it "returns true for known dependency" do
        expect(snapshot.dependency_used?("rake")).to be true
      end

      it "returns false for unknown dependency" do
        expect(snapshot.dependency_used?("unknown")).to be false
      end
    end
  end
end
