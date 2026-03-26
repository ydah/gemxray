# frozen_string_literal: true

require "yaml"

module GemXray
  class RailsKnowledge
    Change = Struct.new(:gem_name, :since, :reason, :source, keyword_init: true)

    def initialize(data_path: File.join(GemXray.root, "data", "rails_changes.yml"))
      @data_path = data_path
    end

    def changes_for(rails_version)
      return [] unless rails_version

      data.fetch("versions", {}).each_with_object([]) do |(since, payload), changes|
        next if Gem::Version.new(rails_version) < Gem::Version.new(since)

        Array(payload["removals"]).each do |item|
          changes << Change.new(
            gem_name: item.fetch("gem"),
            since: since,
            reason: item.fetch("reason"),
            source: item["source"]
          )
        end
      end
    rescue ArgumentError
      []
    end

    def find_removal(gem_name, rails_version)
      changes_for(rails_version).reverse.find { |change| change.gem_name == gem_name }
    end

    private

    def data
      @data ||= YAML.safe_load(File.read(@data_path))
    end
  end
end
