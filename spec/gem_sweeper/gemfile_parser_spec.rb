# frozen_string_literal: true

RSpec.describe GemSweeper::GemfileParser do
  it "parses gem entries, dependency tree, and runtime versions" do
    with_project(sample_project_files) do |project_dir|
      parser = described_class.new(File.join(project_dir, "Gemfile"))
      gems = parser.parse

      mail = gems.find { |entry| entry.name == "mail" }
      awesome_print = gems.find { |entry| entry.name == "awesome_print" }

      expect(mail.line_number).to eq(4)
      expect(mail.groups).to eq([])
      expect(awesome_print.groups).to contain_exactly(:development, :test)
      expect(parser.dependency_tree.fetch("mail").map(&:name)).to include("net-imap", "net-pop", "net-smtp")
      expect(parser.ruby_version).to eq("3.2.2")
      expect(parser.rails_version(gems)).to eq("7.1.3")
    end
  end

  it "captures multiline declaration ranges and inline options" do
    with_project(multiline_project_files) do |project_dir|
      parser = described_class.new(File.join(project_dir, "Gemfile"))
      gems = parser.parse

      mail = gems.find { |entry| entry.name == "mail" }
      fancy_tool = gems.find { |entry| entry.name == "fancy_tool" }
      awesome_print = gems.find { |entry| entry.name == "awesome_print" }

      expect(mail.line_number).to eq(4)
      expect(mail.end_line).to eq(6)
      expect(mail.require_names).to include("mail")

      expect(fancy_tool.line_number).to eq(7)
      expect(fancy_tool.end_line).to eq(9)
      expect(fancy_tool.require_names).to eq([])
      expect(fancy_tool.options).to include(github: "example/fancy_tool", require: false)

      expect(awesome_print.groups).to include(:development, :test)
      expect(awesome_print.end_line).to eq(13)
    end
  end
end
