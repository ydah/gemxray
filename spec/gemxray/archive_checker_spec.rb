# frozen_string_literal: true

RSpec.describe GemXray::ArchiveChecker do
  def stub_github_response(body:, code: "200")
    response = instance_double(Net::HTTPResponse, body: body, code: code)
    allow(response).to receive(:[]).with("location").and_return(nil)

    http = instance_double(Net::HTTP)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_return(response)
    allow(Net::HTTP).to receive(:start) { |*, &block| block.call(http) }

    response
  end

  describe "#check" do
    it "returns archived=true for archived repos" do
      stub_github_response(body: '{"archived":true}')

      checker = described_class.new(token: "test_token")
      result = checker.check("owner/archived-repo")

      expect(result.archived).to be true
      expect(result.error).to be_nil
    end

    it "returns archived=false for active repos" do
      stub_github_response(body: '{"archived":false}')

      checker = described_class.new(token: "test_token")
      result = checker.check("owner/active-repo")

      expect(result.archived).to be false
      expect(result.error).to be_nil
    end

    it "returns error for not found repos" do
      stub_github_response(body: '{"message":"Not Found"}', code: "404")

      checker = described_class.new(token: "test_token")
      result = checker.check("owner/missing-repo")

      expect(result.archived).to be_nil
      expect(result.error).to eq("repository not found")
    end

    it "returns error for auth failures" do
      stub_github_response(body: '{"message":"Bad credentials"}', code: "401")

      checker = described_class.new(token: "bad_token")
      result = checker.check("owner/repo")

      expect(result.error).to eq("authentication failed")
    end

    it "returns error for rate limiting" do
      stub_github_response(body: '{"message":"rate limit exceeded"}', code: "403")

      checker = described_class.new(token: "test_token")
      result = checker.check("owner/repo")

      expect(result.error).to eq("rate limit exceeded or access denied")
    end

    it "handles network errors" do
      allow(Net::HTTP).to receive(:start).and_raise(SocketError.new("connection refused"))

      checker = described_class.new(token: "test_token")
      result = checker.check("owner/repo")

      expect(result.archived).to be_nil
      expect(result.error).to eq("connection refused")
    end

    it "works without a token" do
      stub_github_response(body: '{"archived":false}')

      checker = described_class.new(token: nil)
      result = checker.check("owner/repo")

      expect(result.archived).to be false
    end
  end
end
