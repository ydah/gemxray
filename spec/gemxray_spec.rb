# frozen_string_literal: true

RSpec.describe GemXray do
  it "has a version number" do
    expect(GemXray::VERSION).not_to be_nil
  end

  it "scans a project and merges reasons per gem" do
    with_project(sample_project_files) do |project_dir|
      report = GemXray::Scanner.new(build_config(project_dir)).run

      net_imap = report.results.find { |result| result.gem_name == "net-imap" }
      awesome_print = report.results.find { |result| result.gem_name == "awesome_print" }

      expect(net_imap).not_to be_nil
      expect(net_imap.severity).to eq(:danger)
      expect(net_imap.reason_types).to include(:unused, :redundant, :version_redundant)

      expect(awesome_print).not_to be_nil
      expect(awesome_print.severity).to eq(:warning)

      expect(report.summary).to include(total: be >= 2, danger: be >= 1, warning: be >= 1)
    end
  end
end
