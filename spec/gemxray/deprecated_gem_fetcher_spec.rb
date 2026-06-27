# frozen_string_literal: true

RSpec.describe GemXray::DeprecatedGemFetcher do
  def http_response(body:, success: true)
    response = instance_double(success ? Net::HTTPSuccess : Net::HTTPNotFound, body: body)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(success)
    response
  end

  describe "#fetch" do
    it "reads yanked and post_install_message from the RubyGems version API" do
      allow(Net::HTTP).to receive(:get_response).and_return(
        http_response(
          body: JSON.generate(
            "name" => "old_gem",
            "version" => "1.0.0",
            "yanked" => true,
            "post_install_message" => "This gem is deprecated. Use new_gem instead."
          )
        )
      )

      result = described_class.new(check_readme: false).fetch("old_gem", version: "1.0.0")

      expect(result.version).to eq("1.0.0")
      expect(result.yanked).to be true
      expect(result.post_install_deprecated?).to be true
      expect(result.deprecated?).to be true
    end

    it "detects README deprecation text from GitHub metadata" do
      responses = [
        http_response(
          body: JSON.generate(
            "name" => "readme_gem",
            "version" => "2.0.0",
            "yanked" => false,
            "metadata" => { "source_code_uri" => "https://github.com/example/readme_gem" }
          )
        ),
        http_response(body: "# readme_gem\n\nThis gem is deprecated. Use maintained_gem instead.\n")
      ]
      allow(Net::HTTP).to receive(:get_response) { responses.shift }

      result = described_class.new.fetch("readme_gem", version: "2.0.0")

      expect(result.readme_deprecated).to be true
      expect(result.readme_url).to eq("https://raw.githubusercontent.com/example/readme_gem/HEAD/README.md")
      expect(result.deprecated?).to be true
    end

    it "returns non-deprecated info when RubyGems API fails" do
      allow(Net::HTTP).to receive(:get_response).and_return(http_response(body: "not found", success: false))

      result = described_class.new.fetch("missing_gem", version: "9.9.9")

      expect(result.yanked).to be false
      expect(result.post_install_deprecated?).to be false
      expect(result.readme_deprecated).to be false
      expect(result.deprecated?).to be false
      expect(result.source).to eq(:unknown)
    end
  end
end
