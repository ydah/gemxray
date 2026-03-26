# frozen_string_literal: true

RSpec.describe GemXray::Report do
  def build_result(gem_name:, severity:)
    GemXray::Result.new(
      gem_name: gem_name,
      severity: severity,
      reasons: [GemXray::Result::Reason.new(type: :unused, detail: "test", severity: severity)]
    )
  end

  let(:results) do
    [
      build_result(gem_name: "foo", severity: :danger),
      build_result(gem_name: "bar", severity: :warning),
      build_result(gem_name: "baz", severity: :warning),
      build_result(gem_name: "qux", severity: :info)
    ]
  end

  let(:report) do
    described_class.new(
      version: "0.1.0",
      ruby_version: "3.2.2",
      rails_version: "7.1.3",
      scanned_at: "2026-01-01T00:00:00+00:00",
      results: results
    )
  end

  describe "#summary" do
    it "counts results by severity" do
      summary = report.summary

      expect(summary[:total]).to eq(4)
      expect(summary[:danger]).to eq(1)
      expect(summary[:warning]).to eq(2)
      expect(summary[:info]).to eq(1)
    end

    it "returns all zeros for empty results" do
      empty_report = described_class.new(
        version: "0.1.0",
        ruby_version: "3.2.2",
        rails_version: nil,
        scanned_at: "2026-01-01T00:00:00+00:00",
        results: []
      )

      expect(empty_report.summary).to eq({ total: 0, danger: 0, warning: 0, info: 0 })
    end
  end

  describe "#to_h" do
    it "returns a complete hash representation" do
      hash = report.to_h

      expect(hash[:version]).to eq("0.1.0")
      expect(hash[:ruby_version]).to eq("3.2.2")
      expect(hash[:rails_version]).to eq("7.1.3")
      expect(hash[:scanned_at]).to eq("2026-01-01T00:00:00+00:00")
      expect(hash[:results]).to be_an(Array)
      expect(hash[:results].length).to eq(4)
      expect(hash[:summary]).to eq({ total: 4, danger: 1, warning: 2, info: 1 })
    end

    it "serializes each result via its to_h" do
      hash = report.to_h
      first = hash[:results].first

      expect(first).to have_key(:gem_name)
      expect(first).to have_key(:severity)
      expect(first).to have_key(:reasons)
    end
  end

  describe "attribute readers" do
    it "exposes version, ruby_version, rails_version, scanned_at, results" do
      expect(report.version).to eq("0.1.0")
      expect(report.ruby_version).to eq("3.2.2")
      expect(report.rails_version).to eq("7.1.3")
      expect(report.scanned_at).to eq("2026-01-01T00:00:00+00:00")
      expect(report.results.length).to eq(4)
    end
  end
end
