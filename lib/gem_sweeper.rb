# frozen_string_literal: true

require "time"

require_relative "gem_sweeper/version"
require_relative "gem_sweeper/gem_entry"
require_relative "gem_sweeper/config"
require_relative "gem_sweeper/result"
require_relative "gem_sweeper/report"
require_relative "gem_sweeper/gemfile_source_parser"
require_relative "gem_sweeper/gemfile_parser"
require_relative "gem_sweeper/dependency_resolver"
require_relative "gem_sweeper/code_scanner"
require_relative "gem_sweeper/gem_metadata_resolver"
require_relative "gem_sweeper/stdgems_client"
require_relative "gem_sweeper/rails_knowledge"
require_relative "gem_sweeper/analyzers/base"
require_relative "gem_sweeper/analyzers/unused_analyzer"
require_relative "gem_sweeper/analyzers/redundant_analyzer"
require_relative "gem_sweeper/analyzers/version_analyzer"
require_relative "gem_sweeper/scanner"
require_relative "gem_sweeper/formatters/terminal"
require_relative "gem_sweeper/formatters/json"
require_relative "gem_sweeper/formatters/yaml"
require_relative "gem_sweeper/editors/gemfile_editor"
require_relative "gem_sweeper/editors/github_api_client"
require_relative "gem_sweeper/editors/github_pr"
require_relative "gem_sweeper/cli"

module GemSweeper
  class Error < StandardError; end

  def self.root
    File.expand_path("..", __dir__)
  end
end
