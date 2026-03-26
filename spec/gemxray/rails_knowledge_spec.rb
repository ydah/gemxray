# frozen_string_literal: true

RSpec.describe GemXray::RailsKnowledge do
  subject(:knowledge) { described_class.new }

  describe "#changes_for" do
    it "returns changes applicable to the given Rails version" do
      changes = knowledge.changes_for("7.1.3")

      gem_names = changes.map(&:gem_name)
      expect(gem_names).to include("zeitwerk")
      expect(gem_names).not_to include("sprockets-rails", "bootsnap")
    end

    it "does not include changes from newer Rails versions" do
      changes = knowledge.changes_for("7.0.0")

      gem_names = changes.map(&:gem_name)
      expect(gem_names).to include("zeitwerk")
      expect(gem_names).not_to include("bootsnap")
    end

    it "returns empty array when rails_version is nil" do
      expect(knowledge.changes_for(nil)).to eq([])
    end

    it "returns Change structs with gem_name, since, reason, and source" do
      changes = knowledge.changes_for("7.1.0")
      change = changes.find { |c| c.gem_name == "zeitwerk" }

      expect(change).not_to be_nil
      expect(change.since).to eq("6.0")
      expect(change.reason).to be_a(String)
      expect(change.reason).not_to be_empty
      expect(change.source).to include("guides.rubyonrails.org")
    end

    it "includes Rails 6.0 removals for later versions" do
      change = knowledge.find_removal("zeitwerk", "7.1.0")

      expect(change).not_to be_nil
      expect(change.since).to eq("6.0")
    end
  end

  describe "#find_removal" do
    it "finds the most recent removal for a gem" do
      change = knowledge.find_removal("zeitwerk", "7.1.0")

      expect(change).not_to be_nil
      expect(change.gem_name).to eq("zeitwerk")
      expect(change.since).to eq("6.0")
    end

    it "returns nil when gem has no removal record" do
      change = knowledge.find_removal("rails", "7.1.0")

      expect(change).to be_nil
    end

    it "returns nil when rails_version is nil" do
      change = knowledge.find_removal("zeitwerk", nil)

      expect(change).to be_nil
    end

    it "returns nil when rails_version is too old" do
      change = knowledge.find_removal("zeitwerk", "5.2.8")

      expect(change).to be_nil
    end
  end
end
