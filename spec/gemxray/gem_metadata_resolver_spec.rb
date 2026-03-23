# frozen_string_literal: true

RSpec.describe GemXray::GemMetadataResolver do
  it "extracts constant candidates and detects railties from installed gem files" do
    Dir.mktmpdir("gem-metadata") do |dir|
      lib_dir = File.join(dir, "lib")
      FileUtils.mkdir_p(lib_dir)
      File.write(File.join(lib_dir, "fancy_thing.rb"), "module FancyThing\n  class Engine < Rails::Engine; end\nend\n")

      spec = Struct.new(:full_gem_path, :require_paths).new(dir, ["lib"])

      allow(Gem::Specification).to receive(:find_all_by_name).with("fancy_thing").and_return([spec])

      resolver = described_class.new

      expect(resolver.constant_candidates_for("fancy_thing")).to include("FancyThing")
      expect(resolver.railtie?("fancy_thing")).to eq(true)
    end
  end
end
