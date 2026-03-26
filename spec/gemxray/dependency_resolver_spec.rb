# frozen_string_literal: true

RSpec.describe GemXray::DependencyResolver do
  Edge = GemXray::GemfileParser::DependencyEdge

  def build_tree(hash)
    hash.transform_values do |deps|
      deps.map { |name, req| Edge.new(name: name, requirement: req) }
    end
  end

  describe "#find_parent" do
    it "finds a direct dependency path" do
      tree = build_tree(
        "rails" => [["actionmailer", ">= 0"]],
        "actionmailer" => [["mail", ">= 2.8"]]
      )
      resolver = described_class.new(tree)

      result = resolver.find_parent(
        target: "mail",
        roots: %w[rails],
        max_depth: 3
      )

      expect(result).not_to be_nil
      expect(result[:gems]).to eq(%w[rails actionmailer mail])
    end

    it "finds a depth-1 dependency" do
      tree = build_tree(
        "rails" => [["actionmailer", ">= 0"]]
      )
      resolver = described_class.new(tree)

      result = resolver.find_parent(
        target: "actionmailer",
        roots: %w[rails],
        max_depth: 1
      )

      expect(result).not_to be_nil
      expect(result[:gems]).to eq(%w[rails actionmailer])
    end

    it "returns nil when target is not in the tree" do
      tree = build_tree("rails" => [["actionmailer", ">= 0"]])
      resolver = described_class.new(tree)

      result = resolver.find_parent(
        target: "unknown",
        roots: %w[rails],
        max_depth: 3
      )

      expect(result).to be_nil
    end

    it "returns nil when depth limit is reached" do
      tree = build_tree(
        "rails" => [["actionmailer", ">= 0"]],
        "actionmailer" => [["mail", ">= 0"]],
        "mail" => [["net-imap", ">= 0"]]
      )
      resolver = described_class.new(tree)

      result = resolver.find_parent(
        target: "net-imap",
        roots: %w[rails],
        max_depth: 2
      )

      expect(result).to be_nil
    end

    it "skips root when root equals target" do
      tree = build_tree("mail" => [["net-smtp", ">= 0"]])
      resolver = described_class.new(tree)

      result = resolver.find_parent(
        target: "mail",
        roots: %w[mail net-smtp],
        max_depth: 2
      )

      expect(result).to be_nil
    end

    it "handles multiple roots and finds the first match" do
      tree = build_tree(
        "rails" => [["actionmailer", ">= 0"]],
        "mail" => [["net-smtp", ">= 0"]],
        "actionmailer" => [["mail", ">= 0"]]
      )
      resolver = described_class.new(tree)

      result = resolver.find_parent(
        target: "net-smtp",
        roots: %w[rails mail],
        max_depth: 3
      )

      expect(result).not_to be_nil
      expect(result[:gems]).to include("net-smtp")
    end

    it "includes edges in the result" do
      tree = build_tree(
        "rails" => [["actionmailer", ">= 0"]]
      )
      resolver = described_class.new(tree)

      result = resolver.find_parent(
        target: "actionmailer",
        roots: %w[rails],
        max_depth: 2
      )

      expect(result[:edges].length).to eq(1)
      expect(result[:edges].first.name).to eq("actionmailer")
    end

    it "avoids cycles in the dependency tree" do
      tree = build_tree(
        "a" => [["b", ">= 0"]],
        "b" => [["a", ">= 0"], ["c", ">= 0"]]
      )
      resolver = described_class.new(tree)

      result = resolver.find_parent(
        target: "c",
        roots: %w[a],
        max_depth: 5
      )

      expect(result).not_to be_nil
      expect(result[:gems]).to eq(%w[a b c])
    end
  end
end
