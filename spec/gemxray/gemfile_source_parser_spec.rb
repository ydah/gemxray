# frozen_string_literal: true

RSpec.describe GemXray::GemfileSourceParser do
  describe "#parse" do
    it "parses simple gem statements" do
      with_project(
        "Gemfile" => <<~RUBY
          source "https://rubygems.org"

          gem "rails", "~> 7.1"
          gem "puma"
        RUBY
      ) do |dir|
        parser = described_class.new(File.join(dir, "Gemfile"))
        entries = parser.parse

        names = entries.map(&:name)
        expect(names).to contain_exactly("rails", "puma")

        rails = entries.find { |e| e.name == "rails" }
        expect(rails.version).to eq("~> 7.1")
        expect(rails.line_number).to eq(3)
      end
    end

    it "parses gem statements with options" do
      with_project(
        "Gemfile" => <<~RUBY
          source "https://rubygems.org"

          gem "sidekiq", require: false
          gem "pg", group: :production
        RUBY
      ) do |dir|
        parser = described_class.new(File.join(dir, "Gemfile"))
        entries = parser.parse

        sidekiq = entries.find { |e| e.name == "sidekiq" }
        expect(sidekiq.options[:require]).to eq(false)

        pg = entries.find { |e| e.name == "pg" }
        expect(pg.options[:group]).to eq(:production)
      end
    end

    it "parses gems in group blocks" do
      with_project(
        "Gemfile" => <<~RUBY
          source "https://rubygems.org"

          group :development, :test do
            gem "rspec"
            gem "rubocop"
          end
        RUBY
      ) do |dir|
        parser = described_class.new(File.join(dir, "Gemfile"))
        entries = parser.parse

        rspec = entries.find { |e| e.name == "rspec" }
        expect(rspec.groups).to eq(%i[development test])

        rubocop = entries.find { |e| e.name == "rubocop" }
        expect(rubocop.groups).to eq(%i[development test])
      end
    end

    it "parses multiline gem statements" do
      with_project(
        "Gemfile" => <<~RUBY
          source "https://rubygems.org"

          gem "mail",
            require: ["mail"],
            group: :production
        RUBY
      ) do |dir|
        parser = described_class.new(File.join(dir, "Gemfile"))
        entries = parser.parse

        mail = entries.find { |e| e.name == "mail" }
        expect(mail).not_to be_nil
        expect(mail.options[:require]).to eq(["mail"])
        expect(mail.line_number).to eq(3)
        expect(mail.end_line).to eq(5)
      end
    end

    it "ignores commented-out gem lines" do
      with_project(
        "Gemfile" => <<~RUBY
          source "https://rubygems.org"

          gem "rails"
          # gem "unused"
        RUBY
      ) do |dir|
        parser = described_class.new(File.join(dir, "Gemfile"))
        entries = parser.parse

        names = entries.map(&:name)
        expect(names).to eq(["rails"])
      end
    end

    it "handles nested blocks correctly" do
      with_project(
        "Gemfile" => <<~RUBY
          source "https://rubygems.org"

          group :development do
            gem "pry"

            platforms :ruby do
              gem "byebug"
            end
          end

          gem "rails"
        RUBY
      ) do |dir|
        parser = described_class.new(File.join(dir, "Gemfile"))
        entries = parser.parse

        pry = entries.find { |e| e.name == "pry" }
        expect(pry.groups).to eq([:development])

        byebug = entries.find { |e| e.name == "byebug" }
        expect(byebug.groups).to eq([:development])

        rails = entries.find { |e| e.name == "rails" }
        expect(rails.groups).to eq([])
      end
    end

    it "captures source_line for each entry" do
      with_project(
        "Gemfile" => <<~RUBY
          source "https://rubygems.org"

          gem "rails", "~> 7.1"
        RUBY
      ) do |dir|
        parser = described_class.new(File.join(dir, "Gemfile"))
        entries = parser.parse

        rails = entries.find { |e| e.name == "rails" }
        expect(rails.source_line).to include("rails")
      end
    end

    it "parses gem with github option" do
      with_project(
        "Gemfile" => <<~RUBY
          source "https://rubygems.org"

          gem "fancy_tool",
            github: "example/fancy_tool",
            require: false
        RUBY
      ) do |dir|
        parser = described_class.new(File.join(dir, "Gemfile"))
        entries = parser.parse

        tool = entries.find { |e| e.name == "fancy_tool" }
        expect(tool).not_to be_nil
        expect(tool.options[:github]).to eq("example/fancy_tool")
        expect(tool.options[:require]).to eq(false)
      end
    end
  end
end
