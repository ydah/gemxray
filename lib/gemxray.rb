# frozen_string_literal: true

require "time"

require_relative "gemxray/version"
require_relative "gemxray/gem_entry"
require_relative "gemxray/config"
require_relative "gemxray/result"
require_relative "gemxray/report"
require_relative "gemxray/gemfile_source_parser"
require_relative "gemxray/gemfile_parser"
require_relative "gemxray/dependency_resolver"
require_relative "gemxray/code_scanner"
require_relative "gemxray/gem_metadata_resolver"
require_relative "gemxray/stdgems_client"
require_relative "gemxray/rails_knowledge"
require_relative "gemxray/license_fetcher"
require_relative "gemxray/license_matcher"
require_relative "gemxray/repository_finder"
require_relative "gemxray/archive_checker"
require_relative "gemxray/analyzers/base"
require_relative "gemxray/analyzers/unused_analyzer"
require_relative "gemxray/analyzers/redundant_analyzer"
require_relative "gemxray/analyzers/version_analyzer"
require_relative "gemxray/analyzers/license_analyzer"
require_relative "gemxray/analyzers/archive_analyzer"
require_relative "gemxray/scanner"
require_relative "gemxray/formatters/terminal"
require_relative "gemxray/formatters/json"
require_relative "gemxray/formatters/yaml"
require_relative "gemxray/editors/gemfile_editor"
require_relative "gemxray/editors/github_api_client"
require_relative "gemxray/editors/github_pr"
require_relative "gemxray/cli"

module GemXray
  class Error < StandardError; end

  def self.root
    File.expand_path("..", __dir__)
  end
end
