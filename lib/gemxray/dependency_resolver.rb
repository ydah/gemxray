# frozen_string_literal: true

require "set"

module GemXray
  class DependencyResolver
    def initialize(dependency_tree)
      @dependency_tree = dependency_tree
    end

    def find_parent(target:, roots:, max_depth:)
      roots.each do |root|
        next if root == target

        path = find_path(root, target, max_depth)
        return path if path
      end

      nil
    end

    private

    attr_reader :dependency_tree

    def find_path(root, target, max_depth)
      visited = Set.new([root])
      queue = [[root, [root], [], 0]]

      until queue.empty?
        current, path, edges, depth = queue.shift
        next if depth >= max_depth

        Array(dependency_tree[current]).each do |edge|
          child = edge.name
          next if visited.include?(child) && child != target

          return { gems: path + [child], edges: edges + [edge] } if child == target

          visited << child
          queue << [child, path + [child], edges + [edge], depth + 1]
        end
      end

      nil
    end
  end
end
