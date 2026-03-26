# frozen_string_literal: true

require "fileutils"
require "rubygems/package"
require "rubygems/remote_fetcher"
require "rubygems/spec_fetcher"

module GemXray
  class GemMetadataResolver
    CONSTANT_PATTERN = /^\s*(?:class|module)\s+([A-Z][A-Za-z0-9_:]*)/.freeze
    RemotePackage = Struct.new(:full_gem_path, :require_paths, keyword_init: true)

    def initialize(cache_dir: File.join(Dir.home, ".gemxray", "cache", "gem_metadata"),
                   spec_fetcher: Gem::SpecFetcher.fetcher,
                   remote_fetcher: Gem::RemoteFetcher.fetcher)
      @cache_dir = cache_dir
      @spec_fetcher = spec_fetcher
      @remote_fetcher = remote_fetcher
      @constant_cache = {}
      @railtie_cache = {}
      @remote_package_cache = {}
      @remote_fetch_available = true
    end

    def constant_candidates_for(gem_name, version_requirement: nil)
      @constant_cache[cache_key(gem_name, version_requirement)] ||= begin
        defaults = default_constant_candidates(gem_name)
        discovered = gem_sources_for(gem_name, version_requirement).flat_map do |spec|
          extract_constants(spec, gem_name)
        end
        (defaults + discovered).uniq
      rescue StandardError
        default_constant_candidates(gem_name)
      end
    end

    def railtie?(gem_name, version_requirement: nil)
      key = cache_key(gem_name, version_requirement)
      return @railtie_cache[key] if @railtie_cache.key?(key)

      @railtie_cache[key] = gem_sources_for(gem_name, version_requirement).any? do |spec|
        all_ruby_files_for(spec, gem_name).any? do |path|
          File.read(path, encoding: "utf-8").match?(/Rails::(?:Railtie|Engine)/)
        rescue StandardError
          false
        end
      end
    rescue StandardError
      @railtie_cache[key] = false
    end

    private

    attr_reader :cache_dir, :spec_fetcher, :remote_fetcher

    def cache_key(gem_name, version_requirement)
      "#{gem_name}@#{version_requirement || 'latest'}"
    end

    def gem_sources_for(gem_name, version_requirement)
      installed = installed_specs_for(gem_name, version_requirement)
      return installed unless installed.empty?

      remote_package = remote_package_for(gem_name, version_requirement)
      remote_package ? [remote_package] : []
    end

    def installed_specs_for(gem_name, version_requirement)
      requirement = build_requirement(version_requirement)
      Gem::Specification.find_all_by_name(gem_name).select do |spec|
        requirement.satisfied_by?(spec.version)
      end
    rescue StandardError
      []
    end

    def remote_package_for(gem_name, version_requirement)
      return nil unless @remote_fetch_available

      key = cache_key(gem_name, version_requirement)
      return @remote_package_cache[key] if @remote_package_cache.key?(key)

      dependency = Gem::Dependency.new(gem_name, version_requirement || ">= 0")
      found, errors = spec_fetcher.spec_for_dependency(dependency)
      if found.empty?
        @remote_fetch_available = false if errors.any?
        return @remote_package_cache[key] = nil
      end

      spec, source = found.max_by { |(remote_spec, _)| remote_spec.version }
      gem_path = remote_fetcher.download(spec, source.uri, cache_download_dir)
      unpacked_path = unpack_gem(spec, gem_path)
      @remote_package_cache[key] = RemotePackage.new(full_gem_path: unpacked_path, require_paths: Array(spec.require_paths))
    rescue Gem::RemoteFetcher::FetchError, Gem::GemNotFoundException
      @remote_fetch_available = false
      @remote_package_cache[key] = nil
    rescue StandardError
      @remote_package_cache[key] = nil
    end

    def unpack_gem(spec, gem_path)
      unpacked_path = File.join(cache_extract_dir, spec.full_name)
      marker_path = File.join(unpacked_path, ".gemxray-extracted")
      return unpacked_path if File.exist?(marker_path)

      FileUtils.rm_rf(unpacked_path)
      FileUtils.mkdir_p(unpacked_path)
      Gem::Package.new(gem_path).extract_files(unpacked_path)
      File.write(marker_path, spec.full_name)
      unpacked_path
    end

    def cache_download_dir
      File.join(cache_dir, "downloads")
    end

    def cache_extract_dir
      File.join(cache_dir, "extracted")
    end

    def build_requirement(version_requirement)
      Gem::Requirement.new(version_requirement || ">= 0")
    rescue ArgumentError
      Gem::Requirement.default
    end

    def default_constant_candidates(gem_name)
      segments = gem_name.split(%r{[/_-]}).reject(&:empty?)
      return [] if segments.empty?

      camelized = segments.map { |segment| camelize(segment) }
      [camelized.join, camelized.join("::")].uniq
    end

    def extract_constants(spec, gem_name)
      gem_files_for(spec, gem_name).flat_map do |path|
        File.readlines(path, chomp: true, encoding: "utf-8").filter_map do |line|
          line[CONSTANT_PATTERN, 1]
        end
      rescue StandardError
        []
      end.uniq
    end

    def gem_files_for(spec, gem_name)
      require_roots = spec.require_paths.map { |path| File.join(spec.full_gem_path, path) }
      candidates = preferred_entry_files(require_roots, gem_name)
      return candidates unless candidates.empty?

      all_ruby_files_for(spec, gem_name)
    end

    def all_ruby_files_for(spec, gem_name)
      require_roots = spec.require_paths.map { |path| File.join(spec.full_gem_path, path) }
      preferred_entry_files(require_roots, gem_name) + require_roots.flat_map do |root|
        Dir.glob(File.join(root, "**/*.rb"))
      end.take(100)
    end

    def preferred_entry_files(require_roots, gem_name)
      basenames = [
        gem_name,
        gem_name.tr("-", "/"),
        gem_name.tr("-", "_")
      ].uniq

      basenames.flat_map do |basename|
        require_roots.filter_map do |root|
          path = File.join(root, "#{basename}.rb")
          path if File.exist?(path)
        end
      end.uniq
    end

    def camelize(value)
      value.split("_").map { |part| part[0]&.upcase.to_s + part[1..] }.join
    end
  end
end
