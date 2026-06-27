# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module GemXray
  class DeprecatedGemFetcher
    RUBYGEMS_API = "https://rubygems.org/api"
    DEPRECATED_PATTERN = /deprecated/i
    README_DEPRECATED_PATTERN = /this gem is deprecated/i
    README_FILES = %w[README.md README.markdown README.rdoc README.txt README].freeze
    GITHUB_PATTERN = %r{github\.com[/:]([^/]+/[^/.#?]+)}.freeze

    GemDeprecationInfo = Struct.new(
      :name,
      :version,
      :yanked,
      :post_install_message,
      :readme_deprecated,
      :readme_url,
      :source,
      keyword_init: true
    ) do
      def deprecated?
        yanked || post_install_deprecated? || readme_deprecated
      end

      def post_install_deprecated?
        post_install_message.to_s.match?(DEPRECATED_PATTERN)
      end
    end

    def initialize(check_readme: true)
      @check_readme = check_readme
      @cache = {}
    end

    def fetch(gem_name, version: nil)
      cache_key = [gem_name.to_s, version.to_s]
      @cache[cache_key] ||= fetch_uncached(gem_name.to_s, version: version)
    end

    private

    attr_reader :check_readme

    def fetch_uncached(gem_name, version:)
      payload = version ? fetch_version_payload(gem_name, version) : fetch_latest_payload(gem_name)
      return empty_info(gem_name, version) unless payload

      readme_deprecated, readme_url = readme_status(payload)
      GemDeprecationInfo.new(
        name: gem_name,
        version: payload["version"] || payload["number"] || version&.to_s,
        yanked: payload["yanked"] == true,
        post_install_message: post_install_message(payload),
        readme_deprecated: readme_deprecated,
        readme_url: readme_url,
        source: version ? :rubygems_version : :rubygems
      )
    end

    def fetch_version_payload(gem_name, version)
      gem = URI.encode_www_form_component(gem_name)
      number = URI.encode_www_form_component(version.to_s)
      fetch_json(URI("#{RUBYGEMS_API}/v2/rubygems/#{gem}/versions/#{number}.json")) || fetch_latest_payload(gem_name)
    end

    def fetch_latest_payload(gem_name)
      gem = URI.encode_www_form_component(gem_name)
      fetch_json(URI("#{RUBYGEMS_API}/v1/gems/#{gem}.json"))
    end

    def fetch_json(uri)
      response = Net::HTTP.get_response(uri)
      return nil unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue StandardError
      nil
    end

    def fetch_text(uri)
      response = Net::HTTP.get_response(uri)
      return nil unless response.is_a?(Net::HTTPSuccess)

      response.body
    rescue StandardError
      nil
    end

    def post_install_message(payload)
      payload["post_install_message"] || payload.dig("metadata", "post_install_message")
    end

    def readme_status(payload)
      return [false, nil] unless check_readme

      owner_repo = github_owner_repo(payload)
      return [false, nil] unless owner_repo

      README_FILES.each do |filename|
        url = URI("https://raw.githubusercontent.com/#{owner_repo}/HEAD/#{filename}")
        body = fetch_text(url)
        next unless body

        return [body.match?(README_DEPRECATED_PATTERN), url.to_s]
      end

      [false, nil]
    end

    def github_owner_repo(payload)
      url_fields = %w[source_code_uri homepage_uri changelog_uri bug_tracker_uri documentation_uri]
      urls = url_fields.filter_map { |field| payload[field] }
      metadata = payload["metadata"]
      urls.concat(url_fields.filter_map { |field| metadata[field] }) if metadata.is_a?(Hash)

      url = urls.find { |candidate| candidate.to_s.match?(GITHUB_PATTERN) }
      extract_owner_repo(url)
    end

    def extract_owner_repo(url)
      match = url.to_s.match(GITHUB_PATTERN)
      return unless match

      match[1].delete_suffix(".git")
    end

    def empty_info(gem_name, version)
      GemDeprecationInfo.new(
        name: gem_name,
        version: version&.to_s,
        yanked: false,
        post_install_message: nil,
        readme_deprecated: false,
        readme_url: nil,
        source: :unknown
      )
    end
  end
end
