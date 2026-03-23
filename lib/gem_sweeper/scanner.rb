# frozen_string_literal: true

module GemSweeper
  class Scanner
    ANALYZERS = {
      unused: GemSweeper::Analyzers::UnusedAnalyzer,
      redundant: GemSweeper::Analyzers::RedundantAnalyzer,
      version: GemSweeper::Analyzers::VersionAnalyzer
    }.freeze

    def initialize(config)
      @config = config
      @gemfile_parser = GemfileParser.new(config.gemfile_path)
    end

    def run
      gems = gemfile_parser.parse
      results = build_analyzers.flat_map { |analyzer| analyzer.analyze(gems) }
      merged_results = merge_results(results)

      merged_results.each do |result|
        override = config.override_severity_for(result.gem_name)
        result.severity = override if override
      end

      filtered = merged_results.select { |result| config.severity_in_scope?(result.severity) }
      sorted = filtered.sort_by { |result| [result.severity_order, result.gem_name] }

      Report.new(
        version: GemSweeper::VERSION,
        ruby_version: gemfile_parser.ruby_version,
        rails_version: gemfile_parser.rails_version(gems),
        scanned_at: Time.now.iso8601,
        results: sorted
      )
    end

    private

    attr_reader :config, :gemfile_parser

    def build_analyzers
      selected = config.only || ANALYZERS.keys
      code_snapshot = CodeScanner.new(config).scan if selected.include?(:unused)
      dependency_resolver = DependencyResolver.new(gemfile_parser.dependency_tree)
      stdgems_client = StdgemsClient.new
      rails_knowledge = RailsKnowledge.new
      gem_metadata_resolver = GemMetadataResolver.new

      selected.map do |type|
        ANALYZERS.fetch(type).new(
          config: config,
          gemfile_parser: gemfile_parser,
          code_snapshot: code_snapshot,
          dependency_resolver: dependency_resolver,
          stdgems_client: stdgems_client,
          rails_knowledge: rails_knowledge,
          gem_metadata_resolver: gem_metadata_resolver
        )
      end
    end

    def merge_results(results)
      results.each_with_object({}) do |result, merged|
        merged[result.gem_name] =
          if merged.key?(result.gem_name)
            merged[result.gem_name].merge!(result)
          else
            result
          end
      end.values
    end
  end
end
