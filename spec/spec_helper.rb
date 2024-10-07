# frozen_string_literal: true

require "vitess/activerecord/migration"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) do
    RailsSupport.setup
  end

  config.after(:example) do |example|
    puts "Test failed: #{example.full_description}"
    RailsSupport.handle_failure if example.exception
  end
end
