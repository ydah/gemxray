# frozen_string_literal: true

require "fileutils"
require "json"
require "tmpdir"

require "gem_sweeper"

module ProjectFixtureHelper
  def with_project(files)
    Dir.mktmpdir("gem-sweeper") do |dir|
      files.each do |path, content|
        absolute_path = File.join(dir, path)
        FileUtils.mkdir_p(File.dirname(absolute_path))
        File.write(absolute_path, content)
      end
      yield dir
    end
  end

  def sample_project_files
    {
      "Gemfile" => <<~RUBY,
        source "https://rubygems.org"

        gem "rails", "~> 7.1"
        gem "mail"
        gem "net-imap"

        group :development, :test do
          gem "rspec"
          gem "awesome_print"
        end
      RUBY
      "Gemfile.lock" => <<~LOCK,
        GEM
          remote: https://rubygems.org/
          specs:
            actionmailer (7.1.3)
              actionpack (= 7.1.3)
              activejob (= 7.1.3)
              mail (>= 2.8.1)
            actionpack (7.1.3)
            activejob (7.1.3)
            mail (2.8.1)
              net-imap
              net-pop
              net-smtp
            net-imap (0.4.9)
            net-pop (0.1.2)
            net-smtp (0.5.0)
            rails (7.1.3)
              actionmailer (= 7.1.3)

        PLATFORMS
          ruby

        DEPENDENCIES
          awesome_print
          mail
          net-imap
          rails (~> 7.1)
          rspec

        RUBY VERSION
           ruby 3.2.2p53

        BUNDLED WITH
           2.5.10
      LOCK
      "config/application.rb" => <<~RUBY,
        # frozen_string_literal: true

        require "rails"

        module DemoApp
          class Application < Rails::Application
          end
        end
      RUBY
      "app/mailers/user_mailer.rb" => <<~RUBY,
        # frozen_string_literal: true

        Mail::Message.new
      RUBY
    }
  end

  def multiline_project_files
    {
      "Gemfile" => <<~RUBY,
        source "https://rubygems.org"

        gem "rails", "~> 7.1"
        gem "mail",
          require: ["mail"],
          group: :production
        gem "fancy_tool",
          github: "example/fancy_tool",
          require: false

        group :development, :test do
          gem "awesome_print",
            require: false
        end
      RUBY
      "Gemfile.lock" => <<~LOCK,
        GEM
          remote: https://rubygems.org/
          specs:
            actionmailer (7.1.3)
              mail (>= 2.8.1)
            awesome_print (1.9.2)
            fancy_tool (1.0.0)
            mail (2.8.1)
            rails (7.1.3)
              actionmailer (= 7.1.3)

        PLATFORMS
          ruby

        DEPENDENCIES
          awesome_print
          fancy_tool!
          mail
          rails (~> 7.1)

        RUBY VERSION
           ruby 3.2.2p53

        BUNDLED WITH
           2.5.10
      LOCK
      "config/application.rb" => <<~RUBY,
        require "rails"
        Mail::Message
      RUBY
    }
  end

  def incompatible_redundant_project_files
    {
      "Gemfile" => <<~RUBY,
        source "https://rubygems.org"

        gem "mail", "~> 3.0"
        gem "net-imap"
        gem "rails", "~> 7.1"
      RUBY
      "Gemfile.lock" => <<~LOCK,
        GEM
          remote: https://rubygems.org/
          specs:
            actionmailer (7.1.3)
              mail (>= 2.8.1)
            mail (2.8.1)
              net-imap
            net-imap (0.4.9)
            rails (7.1.3)
              actionmailer (= 7.1.3)

        PLATFORMS
          ruby

        DEPENDENCIES
          mail (~> 3.0)
          net-imap
          rails (~> 7.1)

        RUBY VERSION
           ruby 3.2.2p53

        BUNDLED WITH
           2.5.10
      LOCK
      "config/application.rb" => "require \"rails\"\n"
    }
  end

  def build_config(project_dir, **options)
    GemSweeper::Config.load(
      {
        gemfile_path: File.join(project_dir, "Gemfile"),
        config_path: File.join(project_dir, ".gem-sweeper.yml")
      }.merge(options)
    )
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include(ProjectFixtureHelper)
end
