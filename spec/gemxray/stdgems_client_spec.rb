# frozen_string_literal: true

RSpec.describe GemXray::StdgemsClient do
  describe "#default_gems_for" do
    context "with fallback data (no network)" do
      it "returns default gems for Ruby 3.2" do
        client = described_class.new(cache_dir: Dir.mktmpdir("gemxray_test"))

        allow(Net::HTTP).to receive(:get_response).and_return(
          instance_double(Net::HTTPResponse, is_a?: false)
        )

        gems = client.default_gems_for("3.2.2")

        expect(gems).to include("json", "yaml", "set", "uri", "csv")
        expect(gems).to be_an(Array)
      end

      it "returns default gems for Ruby 3.1" do
        client = described_class.new(cache_dir: Dir.mktmpdir("gemxray_test"))

        allow(Net::HTTP).to receive(:get_response).and_return(
          instance_double(Net::HTTPResponse, is_a?: false)
        )

        gems = client.default_gems_for("3.1.0")

        expect(gems).to include("json", "yaml")
      end

      it "returns empty array for unknown version with no network" do
        client = described_class.new(cache_dir: Dir.mktmpdir("gemxray_test"))

        allow(Net::HTTP).to receive(:get_response).and_return(
          instance_double(Net::HTTPResponse, is_a?: false)
        )

        gems = client.default_gems_for("2.5.0")

        expect(gems).to be_an(Array)
      end
    end

    context "with cached data" do
      it "reads from cache when fresh" do
        Dir.mktmpdir("gemxray_test") do |cache_dir|
          cache_path = File.join(cache_dir, "default_gems.json")
          payload = { "default_gems" => { "3.2" => %w[json yaml csv] } }
          File.write(cache_path, JSON.generate(payload))

          client = described_class.new(cache_dir: cache_dir)
          gems = client.default_gems_for("3.2.0")

          expect(gems).to eq(%w[csv json yaml])
        end
      end
    end

    context "with API response" do
      it "parses hash-based payload" do
        Dir.mktmpdir("gemxray_test") do |cache_dir|
          payload = { "default_gems" => { "3.3" => %w[json yaml set] } }
          response = instance_double(
            Net::HTTPSuccess,
            body: JSON.generate(payload)
          )
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          allow(Net::HTTP).to receive(:get_response).and_return(response)

          client = described_class.new(cache_dir: cache_dir)
          gems = client.default_gems_for("3.3.0")

          expect(gems).to eq(%w[json set yaml])
        end
      end

      it "parses array-based payload" do
        Dir.mktmpdir("gemxray_test") do |cache_dir|
          payload = [
            { "name" => "json", "ruby_version" => "3.3.0" },
            { "name" => "yaml", "ruby_version" => "3.3.0" },
            { "name" => "old_gem", "ruby_version" => "3.2.0" }
          ]
          response = instance_double(
            Net::HTTPSuccess,
            body: JSON.generate(payload)
          )
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          allow(Net::HTTP).to receive(:get_response).and_return(response)

          client = described_class.new(cache_dir: cache_dir)
          gems = client.default_gems_for("3.3.0")

          expect(gems).to eq(%w[json yaml])
        end
      end
    end
  end

  describe "#bundled_gems_for" do
    it "returns fallback bundled gems when network fails and no cache" do
      client = described_class.new(cache_dir: Dir.mktmpdir("gemxray_test"))

      allow(Net::HTTP).to receive(:get_response).and_return(
        instance_double(Net::HTTPResponse, is_a?: false)
      )

      gems = client.bundled_gems_for("3.2.0")

      expect(gems).to include("minitest", "rake", "rbs")
    end

    it "returns bundled gems from cached data" do
      Dir.mktmpdir("gemxray_test") do |cache_dir|
        cache_path = File.join(cache_dir, "bundled_gems.json")
        payload = { "bundled_gems" => { "3.2" => %w[minitest power_assert] } }
        File.write(cache_path, JSON.generate(payload))

        client = described_class.new(cache_dir: cache_dir)
        gems = client.bundled_gems_for("3.2.0")

        expect(gems).to eq(%w[minitest power_assert])
      end
    end
  end

  describe "version normalization" do
    it "extracts major.minor from full version" do
      Dir.mktmpdir("gemxray_test") do |cache_dir|
        cache_path = File.join(cache_dir, "default_gems.json")
        payload = { "default_gems" => { "3.2" => %w[json] } }
        File.write(cache_path, JSON.generate(payload))

        client = described_class.new(cache_dir: cache_dir)
        gems = client.default_gems_for("3.2.5p100")

        expect(gems).to eq(%w[json])
      end
    end
  end
end
