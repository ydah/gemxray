# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module GemXray
  class LicenseFetcher
    GemLicenseInfo = Struct.new(:name, :version, :licenses, :source, :homepage, keyword_init: true)

    RUBYGEMS_API = "https://rubygems.org/api/v1/gems/"

    def fetch(gem_name, version: nil)
      info = fetch_from_local_spec(gem_name, version) || fetch_from_rubygems_api(gem_name)
      info || GemLicenseInfo.new(name: gem_name, version: version&.to_s, licenses: [], source: :unknown, homepage: nil)
    end

    private

    def fetch_from_local_spec(gem_name, version)
      spec = find_local_spec(gem_name, version)
      return unless spec

      licenses = normalize_licenses(spec.licenses)
      GemLicenseInfo.new(
        name: gem_name,
        version: spec.version.to_s,
        licenses: licenses,
        source: :local,
        homepage: spec.homepage
      )
    rescue StandardError
      nil
    end

    def find_local_spec(gem_name, version)
      if version
        requirement = Gem::Requirement.new(version.to_s)
        Gem::Specification.find_all_by_name(gem_name).find { |s| requirement.satisfied_by?(s.version) }
      else
        Gem::Specification.find_by_name(gem_name)
      end
    rescue Gem::MissingSpecError
      nil
    end

    def fetch_from_rubygems_api(gem_name)
      uri = URI("#{RUBYGEMS_API}#{gem_name}.json")
      response = Net::HTTP.get_response(uri)
      return unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      licenses = normalize_licenses(data["licenses"] || [])

      GemLicenseInfo.new(
        name: gem_name,
        version: data["version"],
        licenses: licenses,
        source: :rubygems,
        homepage: data["homepage_uri"] || data["project_uri"]
      )
    rescue StandardError
      nil
    end

    def normalize_licenses(licenses)
      Array(licenses).map(&:to_s).reject(&:empty?).uniq
    end
  end
end
