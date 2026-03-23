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
      expect(parser.dependency_tree.fetch("mail")).to include("net-imap", "net-pop", "net-smtp")
      expect(parser.ruby_version).to eq("3.2.2")
      expect(parser.rails_version(gems)).to eq("7.1.3")
    end
  end
end
