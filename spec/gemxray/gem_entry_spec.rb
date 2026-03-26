# frozen_string_literal: true

RSpec.describe GemXray::GemEntry do
  describe "#initialize" do
    it "stores name and defaults" do
      entry = described_class.new(name: "rails")

      expect(entry.name).to eq("rails")
      expect(entry.version).to be_nil
      expect(entry.groups).to eq([])
      expect(entry.line_number).to be_nil
      expect(entry.end_line).to be_nil
      expect(entry.source_line).to be_nil
      expect(entry.autorequire).to be_nil
      expect(entry.options).to eq({})
    end

    it "stores all provided attributes" do
      entry = described_class.new(
        name: "rspec",
        version: "~> 3.12",
        groups: [:development, :test],
        line_number: 5,
        end_line: 7,
        source_line: 'gem "rspec", "~> 3.12"',
        autorequire: "rspec/autorun",
        options: { require: false }
      )

      expect(entry.name).to eq("rspec")
      expect(entry.version).to eq("~> 3.12")
      expect(entry.groups).to eq(%i[development test])
      expect(entry.line_number).to eq(5)
      expect(entry.end_line).to eq(7)
      expect(entry.source_line).to eq('gem "rspec", "~> 3.12"')
      expect(entry.autorequire).to eq("rspec/autorun")
    end

    it "normalizes version >= 0 to nil" do
      entry = described_class.new(name: "foo", version: ">= 0")
      expect(entry.version).to be_nil
    end

    it "normalizes empty version to nil" do
      entry = described_class.new(name: "foo", version: "  ")
      expect(entry.version).to be_nil
    end

    it "converts string groups to symbols and removes :default" do
      entry = described_class.new(name: "foo", groups: ["default", "development", "test"])
      expect(entry.groups).to eq(%i[development test])
    end

    it "deduplicates groups" do
      entry = described_class.new(name: "foo", groups: [:test, :test, :development])
      expect(entry.groups).to eq(%i[test development])
    end

    it "defaults end_line to line_number" do
      entry = described_class.new(name: "foo", line_number: 10)
      expect(entry.end_line).to eq(10)
    end
  end

  describe "#pinned_version?" do
    it "returns true when version is set" do
      entry = described_class.new(name: "foo", version: "~> 1.0")
      expect(entry.pinned_version?).to be true
    end

    it "returns false when version is nil" do
      entry = described_class.new(name: "foo")
      expect(entry.pinned_version?).to be false
    end
  end

  describe "#development_group?" do
    it "returns true when in development group" do
      entry = described_class.new(name: "foo", groups: [:development])
      expect(entry.development_group?).to be true
    end

    it "returns true when in test group" do
      entry = described_class.new(name: "foo", groups: [:test])
      expect(entry.development_group?).to be true
    end

    it "returns false when in production group" do
      entry = described_class.new(name: "foo", groups: [:production])
      expect(entry.development_group?).to be false
    end

    it "returns false when no groups" do
      entry = described_class.new(name: "foo")
      expect(entry.development_group?).to be false
    end
  end

  describe "#gemfile_group" do
    it "returns nil when no groups" do
      entry = described_class.new(name: "foo")
      expect(entry.gemfile_group).to be_nil
    end

    it "returns single group as string" do
      entry = described_class.new(name: "foo", groups: [:development])
      expect(entry.gemfile_group).to eq("development")
    end

    it "returns multiple groups as array of strings" do
      entry = described_class.new(name: "foo", groups: %i[development test])
      expect(entry.gemfile_group).to eq(%w[development test])
    end
  end

  describe "#line_range" do
    it "returns nil when no line_number" do
      entry = described_class.new(name: "foo")
      expect(entry.line_range).to be_nil
    end

    it "returns range from line_number to end_line" do
      entry = described_class.new(name: "foo", line_number: 5, end_line: 8)
      expect(entry.line_range).to eq(5..8)
    end

    it "returns single-line range when end_line equals line_number" do
      entry = described_class.new(name: "foo", line_number: 5)
      expect(entry.line_range).to eq(5..5)
    end
  end

  describe "#require_names" do
    it "returns empty array when autorequire is false" do
      entry = described_class.new(name: "foo", autorequire: false)
      expect(entry.require_names).to eq([])
    end

    it "returns default require names when autorequire is nil" do
      entry = described_class.new(name: "my-cool-gem")
      expect(entry.require_names).to contain_exactly("my-cool-gem", "my/cool/gem", "my_cool_gem")
    end

    it "returns custom autorequire as array" do
      entry = described_class.new(name: "foo", autorequire: ["bar", "baz"])
      expect(entry.require_names).to eq(%w[bar baz])
    end

    it "deduplicates default require names" do
      entry = described_class.new(name: "simple")
      expect(entry.require_names).to eq(["simple"])
    end
  end
end
