# frozen_string_literal: true

RSpec.describe GemXray::Editors::GemfileEditor do
  it "removes matched gem lines and writes a backup" do
    with_project(sample_project_files) do |project_dir|
      gemfile_path = File.join(project_dir, "Gemfile")
      result = GemXray::Result.new(
        gem_name: "net-imap",
        gemfile_line: 5,
        reasons: [GemXray::Result::Reason.new(type: :unused, detail: "unused", severity: :danger)],
        severity: :danger
      )

      outcome = described_class.new(gemfile_path).apply([result], dry_run: false, comment: false, backup: true)

      expect(outcome.removed).to eq(["net-imap"])
      expect(File.read(gemfile_path)).not_to include('gem "net-imap"')
      expect(File.exist?("#{gemfile_path}.bak")).to eq(true)
    end
  end

  it "can leave a comment instead of deleting the line" do
    with_project(sample_project_files) do |project_dir|
      gemfile_path = File.join(project_dir, "Gemfile")
      result = GemXray::Result.new(
        gem_name: "net-imap",
        gemfile_line: 5,
        reasons: [GemXray::Result::Reason.new(type: :unused, detail: "unused", severity: :danger)],
        severity: :danger
      )

      described_class.new(gemfile_path).apply([result], dry_run: false, comment: true, backup: false)

      expect(File.read(gemfile_path)).to include("# Removed by gemxray: net-imap")
    end
  end

  it "removes multiline declarations using the full source range" do
    with_project(multiline_project_files) do |project_dir|
      gemfile_path = File.join(project_dir, "Gemfile")
      parser = GemXray::GemfileParser.new(gemfile_path)
      fancy_tool = parser.parse.find { |entry| entry.name == "fancy_tool" }
      result = GemXray::Result.new(
        gem_name: "fancy_tool",
        gemfile_line: fancy_tool.line_number,
        gemfile_end_line: fancy_tool.end_line,
        reasons: [GemXray::Result::Reason.new(type: :unused, detail: "unused", severity: :danger)],
        severity: :danger
      )

      described_class.new(gemfile_path).apply([result], dry_run: false, comment: false, backup: false)

      expect(File.read(gemfile_path)).not_to include('gem "fancy_tool"')
      expect(File.read(gemfile_path)).not_to include('github: "example/fancy_tool"')
    end
  end
end
