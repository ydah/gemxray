# frozen_string_literal: true

require "rubygems/package"
require "stringio"
require "uri"

RSpec.describe GemXray::GemMetadataResolver do
  it "extracts constant candidates and detects railties from installed gem files" do
    Dir.mktmpdir("gem-metadata") do |dir|
      lib_dir = File.join(dir, "lib")
      FileUtils.mkdir_p(lib_dir)
      File.write(File.join(lib_dir, "fancy_thing.rb"), "module FancyThing\n  class Engine < Rails::Engine; end\nend\n")

      spec = Struct.new(:full_gem_path, :require_paths, :version).new(dir, ["lib"], Gem::Version.new("1.0.0"))

      allow(Gem::Specification).to receive(:find_all_by_name).with("fancy_thing").and_return([spec])

      resolver = described_class.new

      expect(resolver.constant_candidates_for("fancy_thing")).to include("FancyThing")
      expect(resolver.railtie?("fancy_thing")).to eq(true)
    end
  end

  it "falls back to a remote gem package when the gem is not installed locally" do
    Dir.mktmpdir("gem-metadata") do |dir|
      gem_path, spec = build_remote_gem(dir, "fancy_remote", "1.2.3")
      source = instance_double("GemSource", uri: URI("https://rubygems.org/"))
      spec_fetcher = instance_double(Gem::SpecFetcher)
      remote_fetcher = instance_double(Gem::RemoteFetcher, download: gem_path)

      allow(spec_fetcher).to receive(:spec_for_dependency) do |dependency|
        expect(dependency.name).to eq("fancy_remote")
        expect(dependency.requirement.to_s).to eq("~> 1.2")
        [[[spec, source]], []]
      end
      allow(Gem::Specification).to receive(:find_all_by_name).with("fancy_remote").and_return([])

      resolver = described_class.new(
        cache_dir: File.join(dir, "cache"),
        spec_fetcher: spec_fetcher,
        remote_fetcher: remote_fetcher
      )

      expect(resolver.constant_candidates_for("fancy_remote", version_requirement: "~> 1.2")).to include("FancyRemote")
      expect(resolver.railtie?("fancy_remote", version_requirement: "~> 1.2")).to eq(true)
    end
  end

  def build_remote_gem(dir, name, version)
    lib_dir = File.join(dir, "build", "lib")
    FileUtils.mkdir_p(lib_dir)
    File.write(
      File.join(lib_dir, "#{name}.rb"),
      "module FancyRemote\n  class Engine < Rails::Engine; end\nend\n"
    )

    spec = Gem::Specification.new do |gem_spec|
      gem_spec.name = name
      gem_spec.version = version
      gem_spec.summary = "test gem"
      gem_spec.author = "gemxray"
      gem_spec.files = ["lib/#{name}.rb"]
      gem_spec.require_paths = ["lib"]
    end

    gem_path = nil
    original_stdout = $stdout
    $stdout = StringIO.new
    Dir.chdir(File.join(dir, "build")) do
      gem_path = File.join(Dir.pwd, Gem::Package.build(spec, true))
    end
    $stdout = original_stdout

    [gem_path, spec]
  ensure
    $stdout = original_stdout if defined?(original_stdout) && original_stdout
  end
end
