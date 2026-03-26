# frozen_string_literal: true

RSpec.describe GemXray::Formatters::Yaml do
  describe "#render" do
    it "renders a report as YAML" do
      result = GemXray::Result.new(
        gem_name: "bar",
        severity: :danger,
        reasons: [GemXray::Result::Reason.new(type: :redundant, detail: "dup dep", severity: :danger)]
      )
      report = GemXray::Report.new(
        version: "0.1.0",
        ruby_version: "3.2.2",
        rails_version: "7.1.3",
        scanned_at: "2026-01-01T00:00:00+00:00",
        results: [result]
      )

      output = described_class.new.render(report)
      parsed = YAML.safe_load(output, permitted_classes: [Symbol])

      expect(parsed[:version]).to eq("0.1.0")
      expect(parsed[:ruby_version]).to eq("3.2.2")
      expect(parsed[:results].length).to eq(1)
      expect(parsed[:results].first[:gem_name]).to eq("bar")
      expect(parsed[:summary][:total]).to eq(1)
      expect(parsed[:summary][:danger]).to eq(1)
    end

    it "renders empty results" do
      report = GemXray::Report.new(
        version: "0.1.0",
        ruby_version: "3.2.2",
        rails_version: nil,
        scanned_at: "2026-01-01T00:00:00+00:00",
        results: []
      )

      output = described_class.new.render(report)
      parsed = YAML.safe_load(output, permitted_classes: [Symbol])

      expect(parsed[:results]).to eq([])
      expect(parsed[:summary][:total]).to eq(0)
    end

    it "produces valid YAML" do
      report = GemXray::Report.new(
        version: "0.1.0",
        ruby_version: "3.2.2",
        rails_version: nil,
        scanned_at: "2026-01-01T00:00:00+00:00",
        results: []
      )

      output = described_class.new.render(report)

      expect { YAML.safe_load(output, permitted_classes: [Symbol]) }.not_to raise_error
    end
  end
end
