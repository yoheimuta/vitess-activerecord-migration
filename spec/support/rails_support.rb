# frozen_string_literal: true

require "fileutils"

class RailsSupport
  # Configure the database connection in the Rails app (using MySQL/Vitess)
  DATABASE_CONFIG = <<~DBCONFIG
    default: &default
      adapter: mysql2
      encoding: utf8
      username: user
      host: endtoend

    test:
      <<: *default
      database: main
  DBCONFIG

  # Configure the Rails app to use the Vitess migration strategy
  INIT_CONFIG = <<~INITCONFIG
    require Rails.root.join("../../lib/vitess/activerecord/migration")

    ActiveRecord::Migration.prepend(Vitess::Activerecord::Migration)
  INITCONFIG

  def initialize
    @rails_root = File.join(File.expand_path("../../", __dir__), "tmp", "test_app")
  end

  def setup
    FileUtils.mkdir_p(@rails_root)
    system("rails new #{@rails_root} --skip-bundle --skip-test --skip-git --skip-spring --skip-listen", exception: true)
    File.write("#{@rails_root}/config/database.yml", DATABASE_CONFIG)
    File.write("#{@rails_root}/config/initializers/migration.rb", INIT_CONFIG)
  end

  def cleanup
    FileUtils.rm_rf(@rails_root)
  end
end
