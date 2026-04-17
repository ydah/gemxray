# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module GemXray
  class RepositoryFinder
    RUBYGEMS_API = "https://rubygems.org/api/v1/gems/"
    GITHUB_PATTERN = %r{github\.com[/:]([^/]+/[^/.]+)}.freeze

    def initialize(overrides: {})
      @overrides = overrides
      @cache = {}
    end

    def find(gem_name)
      @cache[gem_name] ||= resolve(gem_name)
    end

    private

    def resolve(gem_name)
      from_overrides(gem_name) || from_rubygems_api(gem_name)
    end

    def from_overrides(gem_name)
      url = @overrides[gem_name.to_s] || @overrides[gem_name.to_sym]
      extract_owner_repo(url) if url
    end

    def from_rubygems_api(gem_name)
      uri = URI("#{RUBYGEMS_API}#{gem_name}.json")
      response = Net::HTTP.get_response(uri)
      return unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      url_fields = %w[source_code_uri homepage_uri changelog_uri bug_tracker_uri documentation_uri]
      url = url_fields.lazy.filter_map { |field| data[field] }.find { |u| u.match?(GITHUB_PATTERN) }
      extract_owner_repo(url)
    rescue StandardError
      nil
    end

    def extract_owner_repo(url)
      return unless url

      match = url.to_s.match(GITHUB_PATTERN)
      return unless match

      repo = match[1].delete_suffix(".git")
      repo.empty? ? nil : repo
    end
  end
end
