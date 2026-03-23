# frozen_string_literal: true

module GemSweeper
  class GemMetadataResolver
    CONSTANT_PATTERN = /^\s*(?:class|module)\s+([A-Z][A-Za-z0-9_:]*)/.freeze

    def initialize
      @constant_cache = {}
      @railtie_cache = {}
    end

    def constant_candidates_for(gem_name)
      @constant_cache[gem_name] ||= begin
        defaults = default_constant_candidates(gem_name)
        discovered = Gem::Specification.find_all_by_name(gem_name).flat_map do |spec|
          extract_constants(spec, gem_name)
        end
        (defaults + discovered).uniq
      rescue StandardError
        default_constant_candidates(gem_name)
      end
    end

    def railtie?(gem_name)
      return @railtie_cache[gem_name] if @railtie_cache.key?(gem_name)

      @railtie_cache[gem_name] = Gem::Specification.find_all_by_name(gem_name).any? do |spec|
        all_ruby_files_for(spec, gem_name).any? do |path|
          File.read(path, encoding: "utf-8").match?(/Rails::(?:Railtie|Engine)/)
        rescue StandardError
          false
        end
      end
    rescue StandardError
      @railtie_cache[gem_name] = false
    end

    private

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
