# frozen_string_literal: true

RSpec.describe GemXray::Result do
  def build_result(**overrides)
    defaults = {
      gem_name: "foo",
      gemfile_line: 5,
      gemfile_end_line: 5,
      gemfile_group: "development",
      reasons: [
        described_class::Reason.new(type: :unused, detail: "not used", severity: :warning)
      ]
    }
    described_class.new(**defaults.merge(overrides))
  end

  describe "#initialize" do
    it "stores all attributes" do
      result = build_result

      expect(result.gem_name).to eq("foo")
      expect(result.gemfile_line).to eq(5)
      expect(result.gemfile_end_line).to eq(5)
      expect(result.gemfile_group).to eq("development")
    end

    it "defaults suggestion when not provided" do
      result = build_result(suggestion: nil)
      expect(result.suggestion).to eq("Consider removing this entry from Gemfile")
    end

    it "defaults end_line to gemfile_line" do
      result = described_class.new(gem_name: "foo", gemfile_line: 10)
      expect(result.gemfile_end_line).to eq(10)
    end

    it "infers severity from reasons" do
      reasons = [
        described_class::Reason.new(type: :unused, detail: "not used", severity: :info),
        described_class::Reason.new(type: :redundant, detail: "redundant", severity: :danger)
      ]
      result = described_class.new(gem_name: "foo", reasons: reasons)
      expect(result.severity).to eq(:danger)
    end

    it "defaults severity to info when no reasons" do
      result = described_class.new(gem_name: "foo", reasons: [])
      expect(result.severity).to eq(:info)
    end
  end

  describe "#add_reason" do
    it "appends a reason and recalculates severity" do
      result = build_result
      expect(result.severity).to eq(:warning)

      result.add_reason(type: :redundant, detail: "redundant dep", severity: :danger)

      expect(result.reasons.length).to eq(2)
      expect(result.severity).to eq(:danger)
    end
  end

  describe "#merge!" do
    it "merges reasons from another result" do
      result1 = build_result
      result2 = described_class.new(
        gem_name: "foo",
        gemfile_line: 10,
        reasons: [described_class::Reason.new(type: :redundant, detail: "dup", severity: :danger)]
      )

      result1.merge!(result2)

      expect(result1.reasons.length).to eq(2)
      expect(result1.severity).to eq(:danger)
    end

    it "fills in missing gemfile_line from other" do
      result1 = described_class.new(gem_name: "foo", reasons: [])
      result2 = described_class.new(gem_name: "foo", gemfile_line: 10, reasons: [])

      result1.merge!(result2)
      expect(result1.gemfile_line).to eq(10)
    end
  end

  describe "#severity_order" do
    it "returns 0 for danger" do
      result = build_result(severity: :danger)
      expect(result.severity_order).to eq(0)
    end

    it "returns 1 for warning" do
      result = build_result(severity: :warning)
      expect(result.severity_order).to eq(1)
    end

    it "returns 2 for info" do
      result = build_result(severity: :info)
      expect(result.severity_order).to eq(2)
    end
  end

  describe "#reason_types" do
    it "returns unique types from reasons" do
      result = build_result
      result.add_reason(type: :unused, detail: "again", severity: :info)
      result.add_reason(type: :redundant, detail: "dup", severity: :warning)

      expect(result.reason_types).to eq(%i[unused redundant])
    end
  end

  describe "#type_label" do
    it "formats types with dashes and joins with +" do
      result = build_result
      result.add_reason(type: :version_redundant, detail: "v", severity: :info)

      expect(result.type_label).to eq("unused + version-redundant")
    end
  end

  describe "#danger?" do
    it "returns true when severity is danger" do
      result = build_result(severity: :danger)
      expect(result.danger?).to be true
    end

    it "returns false when severity is not danger" do
      result = build_result(severity: :warning)
      expect(result.danger?).to be false
    end
  end

  describe "#info?" do
    it "returns true when severity is info" do
      result = build_result(severity: :info)
      expect(result.info?).to be true
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      result = build_result

      hash = result.to_h

      expect(hash[:gem_name]).to eq("foo")
      expect(hash[:severity]).to eq("warning")
      expect(hash[:reasons]).to be_an(Array)
      expect(hash[:reasons].first[:type]).to eq("unused")
      expect(hash[:gemfile_line]).to eq(5)
      expect(hash[:gemfile_group]).to eq("development")
      expect(hash[:suggestion]).to be_a(String)
    end
  end

  describe GemXray::Result::Reason do
    describe "#to_h" do
      it "returns type and detail" do
        reason = described_class.new(type: :unused, detail: "not used", severity: :warning)

        expect(reason.to_h).to eq({ type: "unused", detail: "not used" })
      end
    end
  end
end
