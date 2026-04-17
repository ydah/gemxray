# frozen_string_literal: true

RSpec.describe GemXray::LicenseMatcher do
  subject(:matcher) { described_class.new }

  describe "#match?" do
    it "matches exact license names" do
      expect(matcher.match?("MIT", ["MIT"])).to be true
    end

    it "matches case-insensitively" do
      expect(matcher.match?("mit", ["MIT"])).to be true
    end

    it "matches via fingerprint normalization" do
      expect(matcher.match?("The MIT License", ["MIT"])).to be true
    end

    it "matches Apache variants" do
      expect(matcher.match?("Apache License, Version 2.0", ["Apache-2.0"])).to be true
    end

    it "returns false when no match found" do
      expect(matcher.match?("GPL-3.0", ["MIT", "Apache-2.0"])).to be false
    end

    it "returns false with empty allowed list" do
      expect(matcher.match?("MIT", [])).to be false
    end

    it "handles BSD variants" do
      expect(matcher.match?("BSD 2-Clause", ["BSD-2-Clause"])).to be true
    end
  end
end
