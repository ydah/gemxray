# frozen_string_literal: true

require "stringio"

RSpec.describe GemXray::CLI do
  def build_report(results)
    GemXray::Report.new(
      version: GemXray::VERSION,
      ruby_version: "3.2.2",
      rails_version: "7.1.3",
      scanned_at: "2026-01-01T00:00:00+00:00",
      results: results
    )
  end

  def build_result(gem_name:, severity:)
    GemXray::Result.new(
      gem_name: gem_name,
      reasons: [GemXray::Result::Reason.new(type: :unused, detail: "unused", severity: severity)],
      severity: severity
    )
  end

  it "returns 1 for scan --ci when findings are present" do
    with_project(sample_project_files) do |project_dir|
      code = described_class.start(
        ["scan", "--ci", "--gemfile", File.join(project_dir, "Gemfile")],
        out: StringIO.new,
        err: StringIO.new,
        stdin: StringIO.new
      )

      expect(code).to eq(1)
    end
  end

  it "uses ci settings from config to decide scan exit status" do
    with_project(
      sample_project_files.merge(
        ".gemxray.yml" => <<~YAML
          ci: true
          ci_fail_on: danger
        YAML
      )
    ) do |project_dir|
      code = described_class.start(
        [
          "scan",
          "--gemfile", File.join(project_dir, "Gemfile"),
          "--config", File.join(project_dir, ".gemxray.yml")
        ],
        out: StringIO.new,
        err: StringIO.new,
        stdin: StringIO.new
      )

      expect(code).to eq(1)
    end
  end

  it "returns 0 for scan --ci --fail-on danger when only warning findings are reported" do
    with_project(sample_project_files) do |project_dir|
      scanner = instance_double(
        GemXray::Scanner,
        run: build_report([build_result(gem_name: "awesome_print", severity: :warning)])
      )

      allow(GemXray::Scanner).to receive(:new).and_return(scanner)

      code = described_class.start(
        ["scan", "--ci", "--fail-on", "danger", "--gemfile", File.join(project_dir, "Gemfile")],
        out: StringIO.new,
        err: StringIO.new,
        stdin: StringIO.new
      )

      expect(code).to eq(0)
    end
  end

  it "renders scan results as json" do
    with_project(sample_project_files) do |project_dir|
      out = StringIO.new
      err = StringIO.new
      code = described_class.start(
        ["scan", "--format", "json", "--gemfile", File.join(project_dir, "Gemfile")],
        out: out,
        err: err,
        stdin: StringIO.new
      )

      payload = JSON.parse(out.string)

      expect(code).to eq(0)
      expect(err.string).to eq("")
      expect(payload.fetch("results").map { |item| item.fetch("gem_name") }).to include("net-imap")
    end
  end

  it "supports clean --auto-fix --dry-run without mutating the Gemfile" do
    with_project(sample_project_files) do |project_dir|
      gemfile_path = File.join(project_dir, "Gemfile")
      before = File.read(gemfile_path)
      out = StringIO.new

      code = described_class.start(
        ["clean", "--auto-fix", "--dry-run", "--gemfile", gemfile_path],
        out: out,
        err: StringIO.new,
        stdin: StringIO.new
      )

      expect(code).to eq(0)
      expect(out.string).to include("net-imap")
      expect(out.string).to include("@@ Gemfile:")
      expect(out.string).to include('-gem "net-imap"')
      expect(File.read(gemfile_path)).to eq(before)
    end
  end

  it "prints top-level help for --help without treating it as an error" do
    out = StringIO.new
    err = StringIO.new

    code = described_class.start(["--help"], out: out, err: err, stdin: StringIO.new)

    expect(code).to eq(0)
    expect(out.string).to include("gemxray [COMMAND] [OPTIONS]")
    expect(err.string).to eq("")
  end

  it "prints command help for scan --help without treating it as an error" do
    out = StringIO.new
    err = StringIO.new

    code = described_class.start(["scan", "--help"], out: out, err: err, stdin: StringIO.new)

    expect(code).to eq(0)
    expect(out.string).to include("Usage: gemxray scan [options]")
    expect(err.string).to eq("")
  end

  it "writes a starter config with init" do
    with_project("Gemfile" => 'source "https://rubygems.org"') do |project_dir|
      out = StringIO.new
      err = StringIO.new

      Dir.chdir(project_dir) do
        code = described_class.start(["init"], out: out, err: err, stdin: StringIO.new)

        expect(code).to eq(0)
        expect(File.read(File.join(project_dir, ".gemxray.yml"))).to include("bundle_install: true")
      end

      expect(out.string).to include("created .gemxray.yml")
      expect(err.string).to eq("")
    end
  end

  it "passes PR options through and reports multiple pull requests" do
    with_project(sample_project_files) do |project_dir|
      report = instance_double(
        GemXray::Report,
        results: [
          GemXray::Result.new(
            gem_name: "net-imap",
            reasons: [GemXray::Result::Reason.new(type: :unused, detail: "unused", severity: :danger)],
            severity: :danger
          ),
          GemXray::Result.new(
            gem_name: "awesome_print",
            reasons: [GemXray::Result::Reason.new(type: :unused, detail: "unused", severity: :warning)],
            severity: :warning
          )
        ]
      )
      scanner = instance_double(GemXray::Scanner, run: report)
      editor = instance_double(
        GemXray::Editors::GithubPr,
        create: {
          branch: "gemxray/cleanup-20260327-net-imap",
          pr_url: "https://example.test/pr/1",
          pull_requests: [
            { gem_name: "net-imap", pr_url: "https://example.test/pr/1", branch: "gemxray/cleanup-20260327-net-imap" },
            { gem_name: "awesome_print", pr_url: "https://example.test/pr/2", branch: "gemxray/cleanup-20260327-awesome-print" }
          ]
        }
      )
      out = StringIO.new
      err = StringIO.new

      allow(GemXray::Scanner).to receive(:new).and_return(scanner)
      allow(GemXray::Editors::GithubPr).to receive(:new).and_return(editor)

      code = described_class.start(
        ["pr", "--gemfile", File.join(project_dir, "Gemfile"), "--per-gem", "--no-bundle"],
        out: out,
        err: err,
        stdin: StringIO.new
      )

      expect(code).to eq(0)
      expect(editor).to have_received(:create).with(
        report.results,
        per_gem: true,
        bundle_install: false,
        comment: false
      )
      expect(out.string).to include("Created 2 PRs:")
      expect(out.string).to include("net-imap: https://example.test/pr/1")
      expect(out.string).to include("awesome_print: https://example.test/pr/2")
      expect(err.string).to eq("")
    end
  end
end
