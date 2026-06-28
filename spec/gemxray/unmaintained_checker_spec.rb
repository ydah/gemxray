# frozen_string_literal: true

RSpec.describe GemXray::UnmaintainedChecker do
  def stub_github_responses(*responses)
    http = instance_double(Net::HTTP)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request) { responses.shift }
    allow(Net::HTTP).to receive(:start) { |*, &block| block.call(http) }
  end

  def github_response(body:, code: "200")
    instance_double(Net::HTTPResponse, body: body, code: code)
  end

  describe "#check" do
    it "returns repository push and latest release timestamps" do
      stub_github_responses(
        github_response(body: JSON.generate("pushed_at" => "2023-01-01T00:00:00Z")),
        github_response(body: JSON.generate("published_at" => "2024-01-01T00:00:00Z"))
      )

      result = described_class.new(token: "test_token").check("owner/repo")

      expect(result.pushed_at).to eq("2023-01-01T00:00:00Z")
      expect(result.latest_release_at).to eq("2024-01-01T00:00:00Z")
      expect(result.last_activity_at).to eq(Time.parse("2024-01-01T00:00:00Z"))
      expect(result.error).to be_nil
    end

    it "uses pushed_at when a repository has no releases" do
      stub_github_responses(
        github_response(body: JSON.generate("pushed_at" => "2023-01-01T00:00:00Z")),
        github_response(body: JSON.generate("message" => "Not Found"), code: "404")
      )

      result = described_class.new(token: nil).check("owner/repo")

      expect(result.latest_release_at).to be_nil
      expect(result.last_activity_at).to eq(Time.parse("2023-01-01T00:00:00Z"))
      expect(result.error).to be_nil
    end

    it "returns repository errors" do
      stub_github_responses(github_response(body: JSON.generate("message" => "Not Found"), code: "404"))

      result = described_class.new(token: nil).check("owner/missing")

      expect(result.error).to eq("repository not found")
    end

    it "classifies old activity as unmaintained" do
      result = described_class::ActivityResult.new(
        owner_repo: "owner/repo",
        pushed_at: "2020-01-01T00:00:00Z",
        latest_release_at: nil
      )

      expect(result.unmaintained?(Time.parse("2022-01-01T00:00:00Z"))).to be true
    end
  end
end
