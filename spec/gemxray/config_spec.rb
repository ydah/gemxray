# frozen_string_literal: true

RSpec.describe GemXray::Config do
  describe ".load" do
    it "returns a Config with defaults when no options given" do
      config = described_class.load(gemfile_path: "/tmp/Gemfile")

      expect(config.format).to eq("terminal")
      expect(config.severity_threshold).to eq(:info)
      expect(config.whitelist).to eq([])
      expect(config.redundant_depth).to eq(2)
      expect(config.auto_fix?).to be false
      expect(config.dry_run?).to be false
      expect(config.ci?).to be false
      expect(config.comment?).to be false
      expect(config.bundle_install?).to be false
    end

    it "merges CLI options over defaults" do
      config = described_class.load(
        gemfile_path: "/tmp/Gemfile",
        format: "json",
        severity: "warning",
        auto_fix: true,
        dry_run: true
      )

      expect(config.format).to eq("json")
      expect(config.severity_threshold).to eq(:warning)
      expect(config.auto_fix?).to be true
      expect(config.dry_run?).to be true
    end

    it "loads config from YAML file" do
      with_project(
        "Gemfile" => 'source "https://rubygems.org"',
        ".gemxray.yml" => <<~YAML
          whitelist:
            - bootsnap
            - tzinfo-data
          overrides:
            puma:
              severity: ignore
        YAML
      ) do |dir|
        config = build_config(dir)

        expect(config.whitelist).to include("bootsnap", "tzinfo-data")
        expect(config.ignore_gem?("puma")).to be true
      end
    end

    it "raises on unknown severity" do
      expect {
        described_class.load(gemfile_path: "/tmp/Gemfile", severity: "critical")
      }.to raise_error(GemXray::Error, /unknown severity/)
    end
  end

  describe "#lockfile_path" do
    it "appends .lock to gemfile_path" do
      config = described_class.load(gemfile_path: "/tmp/Gemfile")
      expect(config.lockfile_path).to eq("/tmp/Gemfile.lock")
    end
  end

  describe "#project_root" do
    it "returns directory of gemfile_path" do
      config = described_class.load(gemfile_path: "/tmp/myproject/Gemfile")
      expect(config.project_root).to eq("/tmp/myproject")
    end
  end

  describe "#whitelisted?" do
    it "returns true for gems in the whitelist" do
      config = described_class.load(gemfile_path: "/tmp/Gemfile", whitelist: ["bootsnap"])
      expect(config.whitelisted?("bootsnap")).to be true
    end

    it "returns false for gems not in the whitelist" do
      config = described_class.load(gemfile_path: "/tmp/Gemfile", whitelist: ["bootsnap"])
      expect(config.whitelisted?("rails")).to be false
    end
  end

  describe "#override_for" do
    it "returns the override hash for a gem" do
      config = described_class.load(
        gemfile_path: "/tmp/Gemfile",
        overrides: { puma: { severity: "ignore" } }
      )

      expect(config.override_for(:puma)).to eq({ severity: "ignore" })
    end

    it "returns nil when no override exists" do
      config = described_class.load(gemfile_path: "/tmp/Gemfile")
      expect(config.override_for(:rails)).to be_nil
    end
  end

  describe "#ignore_gem?" do
    it "returns true when override severity is ignore" do
      config = described_class.load(
        gemfile_path: "/tmp/Gemfile",
        overrides: { puma: { severity: "ignore" } }
      )

      expect(config.ignore_gem?("puma")).to be true
    end

    it "returns false when override severity is not ignore" do
      config = described_class.load(
        gemfile_path: "/tmp/Gemfile",
        overrides: { puma: { severity: "warning" } }
      )

      expect(config.ignore_gem?("puma")).to be false
    end
  end

  describe "#override_severity_for" do
    it "returns normalized severity from override" do
      config = described_class.load(
        gemfile_path: "/tmp/Gemfile",
        overrides: { puma: { severity: "warning" } }
      )

      expect(config.override_severity_for("puma")).to eq(:warning)
    end

    it "returns nil when override severity is ignore" do
      config = described_class.load(
        gemfile_path: "/tmp/Gemfile",
        overrides: { puma: { severity: "ignore" } }
      )

      expect(config.override_severity_for("puma")).to be_nil
    end

    it "returns nil when no override" do
      config = described_class.load(gemfile_path: "/tmp/Gemfile")
      expect(config.override_severity_for("rails")).to be_nil
    end
  end

  describe "#severity_in_scope?" do
    it "returns true when result severity is within threshold" do
      config = described_class.load(gemfile_path: "/tmp/Gemfile", severity: "warning")

      expect(config.severity_in_scope?(:danger)).to be true
      expect(config.severity_in_scope?(:warning)).to be true
      expect(config.severity_in_scope?(:info)).to be false
    end
  end

  describe "#only" do
    it "normalizes comma-separated string to array of symbols" do
      config = described_class.load(
        gemfile_path: "/tmp/Gemfile",
        only: "unused,redundant"
      )

      expect(config.only).to eq(%i[unused redundant])
    end

    it "returns nil when not set" do
      config = described_class.load(gemfile_path: "/tmp/Gemfile")
      expect(config.only).to be_nil
    end
  end

  describe "#scan_dirs" do
    it "includes default scan dirs" do
      config = described_class.load(gemfile_path: "/tmp/Gemfile")
      expect(config.scan_dirs).to include("app", "lib", "config", "spec", "test")
    end

    it "merges custom scan dirs with defaults" do
      config = described_class.load(gemfile_path: "/tmp/Gemfile", scan_dirs: ["engines/billing/app"])
      expect(config.scan_dirs).to include("engines/billing/app")
      expect(config.scan_dirs).to include("app")
    end
  end

  describe "GitHub config" do
    it "has sensible defaults" do
      config = described_class.load(gemfile_path: "/tmp/Gemfile")

      expect(config.github_base_branch).to eq("main")
      expect(config.github_labels).to eq(%w[dependencies cleanup])
      expect(config.github_reviewers).to eq([])
      expect(config.github_per_gem?).to be false
      expect(config.github_bundle_install?).to be true
    end
  end

  describe "boolean flags" do
    it "treats string 'true' as truthy" do
      config = described_class.load(gemfile_path: "/tmp/Gemfile", ci: "true")
      expect(config.ci?).to be true
    end

    it "treats string 'false' as falsy" do
      config = described_class.load(gemfile_path: "/tmp/Gemfile", ci: "false")
      expect(config.ci?).to be false
    end
  end

  describe ".deep_merge" do
    it "deep merges nested hashes" do
      left = { a: { b: 1, c: 2 } }
      right = { a: { c: 3, d: 4 } }

      result = described_class.deep_merge(left, right)

      expect(result).to eq({ a: { b: 1, c: 3, d: 4 } })
    end

    it "concatenates and deduplicates arrays" do
      left = { a: [1, 2] }
      right = { a: [2, 3] }

      result = described_class.deep_merge(left, right)

      expect(result).to eq({ a: [1, 2, 3] })
    end
  end
end
