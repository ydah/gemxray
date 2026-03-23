# frozen_string_literal: true

require "stringio"

RSpec.describe GemSweeper::CLI do
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
      expect(File.read(gemfile_path)).to eq(before)
    end
  end
end
