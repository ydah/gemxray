# frozen_string_literal: true

RSpec.describe GemXray::LicenseFetcher do
  describe "#fetch" do
    it "returns license info from local spec" do
      spec = instance_double(Gem::Specification, version: Gem::Version.new("1.0"), licenses: ["MIT"], homepage: "https://example.com")
      allow(Gem::Specification).to receive(:find_all_by_name).and_return([spec])
      allow(spec).to receive(:version).and_return(Gem::Version.new("1.0"))

      result = described_class.new.fetch("some_gem", version: "~> 1.0")

      expect(result.licenses).to eq(["MIT"])
      expect(result.source).to eq(:local)
    end

    it "falls back to RubyGems API when local spec not found" do
      allow(Gem::Specification).to receive(:find_by_name).and_raise(Gem::MissingSpecError)
      stub_request = instance_double(Net::HTTPSuccess, body: '{"version":"2.0","licenses":["Apache-2.0"],"homepage_uri":"https://example.com"}')
      allow(stub_request).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(Net::HTTP).to receive(:get_response).and_return(stub_request)

      result = described_class.new.fetch("remote_gem")

      expect(result.licenses).to eq(["Apache-2.0"])
      expect(result.source).to eq(:rubygems)
    end

    it "returns unknown source when all sources fail" do
      allow(Gem::Specification).to receive(:find_by_name).and_raise(Gem::MissingSpecError)
      stub_request = instance_double(Net::HTTPNotFound)
      allow(stub_request).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
      allow(Net::HTTP).to receive(:get_response).and_return(stub_request)

      result = described_class.new.fetch("missing_gem")

      expect(result.licenses).to eq([])
      expect(result.source).to eq(:unknown)
    end

    it "normalizes empty and nil licenses" do
      spec = instance_double(Gem::Specification, version: Gem::Version.new("1.0"), licenses: [nil, "", "MIT"], homepage: nil)
      allow(Gem::Specification).to receive(:find_by_name).and_return(spec)

      result = described_class.new.fetch("some_gem")

      expect(result.licenses).to eq(["MIT"])
    end
  end
end
