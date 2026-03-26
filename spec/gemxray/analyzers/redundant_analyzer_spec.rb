# frozen_string_literal: true

RSpec.describe GemXray::Analyzers::RedundantAnalyzer do
  it "reports pinned versions as info when the resolved lockfile version is compatible" do
    files = sample_project_files.dup
    files["Gemfile"] = files["Gemfile"].sub('gem "mail"', 'gem "mail", "~> 2.8"')
    files["Gemfile.lock"] = files["Gemfile.lock"].sub("  mail\n", "  mail (~> 2.8)\n")

    with_project(files) do |project_dir|
      parser = GemXray::GemfileParser.new(File.join(project_dir, "Gemfile"))
      gems = parser.parse
      config = build_config(project_dir)
      resolver = GemXray::DependencyResolver.new(parser.dependency_tree)
      analyzer = described_class.new(
        config: config,
        gemfile_parser: parser,
        dependency_resolver: resolver
      )

      result = analyzer.analyze(gems).find { |entry| entry.gem_name == "mail" }

      expect(result.severity).to eq(:info)
      expect(result.reasons.map(&:detail).any? { |detail| detail.include?("version is pinned in Gemfile") }).to be(true)
    end
  end

  it "skips redundant findings when the pinned version is incompatible with the parent dependency" do
    with_project(incompatible_redundant_project_files) do |project_dir|
      parser = GemXray::GemfileParser.new(File.join(project_dir, "Gemfile"))
      config = build_config(project_dir, only: ["redundant"])
      analyzer = described_class.new(
        config: config,
        gemfile_parser: parser,
        dependency_resolver: GemXray::DependencyResolver.new(parser.dependency_tree)
      )

      result = analyzer.analyze(parser.parse).find { |entry| entry.gem_name == "mail" }

      expect(result).to be_nil
    end
  end
end
