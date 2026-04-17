# frozen_string_literal: true

RSpec.describe GemXray::RepositoryFinder do
  describe "#find" do
    it "returns override when configured" do
      finder = described_class.new(overrides: { "my_gem" => "https://github.com/owner/repo" })

      expect(finder.find("my_gem")).to eq("owner/repo")
    end

    it "extracts owner/repo from GitHub URLs" do
      finder = described_class.new(overrides: { "my_gem" => "https://github.com/foo/bar.git" })

      expect(finder.find("my_gem")).to eq("foo/bar")
    end

    it "falls back to RubyGems API" do
      response = instance_double(Net::HTTPSuccess,
                                 body: '{"source_code_uri":"https://github.com/rails/rails","homepage_uri":"https://rubyonrails.org"}')
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(Net::HTTP).to receive(:get_response).and_return(response)

      finder = described_class.new
      expect(finder.find("rails")).to eq("rails/rails")
    end

    it "returns nil when no GitHub repo found" do
      response = instance_double(Net::HTTPSuccess,
                                 body: '{"source_code_uri":null,"homepage_uri":"https://example.com","changelog_uri":null,"bug_tracker_uri":null,"documentation_uri":null}')
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(Net::HTTP).to receive(:get_response).and_return(response)

      finder = described_class.new
      expect(finder.find("no_github_gem")).to be_nil
    end

    it "caches results" do
      finder = described_class.new(overrides: { "cached_gem" => "https://github.com/a/b" })

      result1 = finder.find("cached_gem")
      result2 = finder.find("cached_gem")

      expect(result1).to eq(result2)
      expect(result1).to eq("a/b")
    end

    it "handles API errors gracefully" do
      response = instance_double(Net::HTTPNotFound)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
      allow(Net::HTTP).to receive(:get_response).and_return(response)

      finder = described_class.new
      expect(finder.find("broken_gem")).to be_nil
    end
  end
end
