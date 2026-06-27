# frozen_string_literal: true

RSpec.describe GemXray::SecurityAdvisoryFetcher do
  describe "#fetch" do
    it "loads advisories from a local ruby-advisory-db checkout" do
      with_project(
        "db/gems/rack/CVE-2020-8161.yml" => <<~YAML
          ---
          gem: rack
          cve: 2020-8161
          title: Directory traversal
          url: https://example.test/CVE-2020-8161
          patched_versions:
            - ">= 2.0.9, < 2.1.0"
            - ">= 2.1.3"
          unaffected_versions:
            - "< 2.0.0"
        YAML
      ) do |dir|
        fetcher = described_class.new(advisory_db_path: File.join(dir, "db"), cache_ttl: 0)

        advisories = fetcher.fetch("rack")

        expect(advisories.length).to eq(1)
        expect(advisories.first.identifier).to eq("CVE-2020-8161")
        expect(advisories.first.title).to eq("Directory traversal")
      end
    end
  end

  describe GemXray::SecurityAdvisoryFetcher::Advisory do
    it "treats patched versions as safe and affected versions as vulnerable" do
      advisory = described_class.new(
        gem_name: "rack",
        cve: "2020-8161",
        patched_versions: [">= 2.0.9, < 2.1.0", ">= 2.1.3"],
        unaffected_versions: ["< 2.0.0"]
      )

      expect(advisory.vulnerable?("2.0.8")).to be true
      expect(advisory.vulnerable?("2.0.9")).to be false
      expect(advisory.vulnerable?("2.1.2")).to be true
      expect(advisory.vulnerable?("2.1.3")).to be false
      expect(advisory.vulnerable?("1.6.13")).to be false
    end

    it "normalizes CVE identifiers" do
      advisory = described_class.new(
        gem_name: "rack",
        cve: "2020-8161",
        patched_versions: [],
        unaffected_versions: []
      )

      expect(advisory.identifier).to eq("CVE-2020-8161")
    end
  end
end
