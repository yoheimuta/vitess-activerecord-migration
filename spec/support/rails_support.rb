# frozen_string_literal: true

require "fileutils"

class RailsSupport
  def initialize
    @rails_root = File.join(File.expand_path("../../", __dir__), "tmp", "endtoend", "rails_app")
    @schema_backup_path = "#{@rails_root}/db/schema_backup.rb"
    @schema_path = "#{@rails_root}/db/schema.rb"
    @migration_files = []
  end

  def self.setup
    @rails_root = File.join(File.expand_path("../../", __dir__), "tmp", "endtoend", "rails_app")
    FileUtils.rm_r(@rails_root, force: true)
    system("bundle exec rails new #{@rails_root} --minimal --skip-bundle --skip-test --skip-git --skip-spring --skip-listen --skip-docker --skip-asset-pipeline", exception: true)

    copy_template_file("Gemfile")
    copy_template_file("config", "database.yml")
    copy_template_file("config", "initializers", "migration.rb")

    Dir.chdir(@rails_root) do
      system("bundle install", exception: true)
      system("RAILS_ENV=test bundle exec rails db:migrate", exception: true)
    end
  end

  def setup
    run("rails db:schema:load")
    ActiveRecord::Base.establish_connection(db_config["test"])

    # Save the current schema
    FileUtils.cp(@schema_path, @schema_backup_path)
  end

  def cleanup
    # Clean up database tables
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{table}")
    end

    # Restore the original schema
    FileUtils.cp(@schema_backup_path, @schema_path)
    FileUtils.rm(@schema_backup_path)

    # Clean up migration files
    @migration_files.each do |f|
      FileUtils.rm(f)
    end
  end

  def run(command, rails_env = "test")
    # Change directory to @rails_root and run the Rails command
    Dir.chdir(@rails_root) do
      append = rails_env ? " RAILS_ENV=#{rails_env}" : ""
      system("#{append} bundle exec #{command}", exception: true)
    end
  end

  def create_test_vitess_users(table_columns = "name:string")
    table_name = "test_vitess_users"
    name = "create_#{table_name}"

    # Create a migration file
    run("rails generate migration #{name.camelize} #{table_columns}")

    # Get the migration file path
    @migration_files = Dir.glob(File.join(@rails_root, "db", "migrate", "*_#{name}.rb"))
    migration_context = File.basename(@migration_files.first, ".rb")

    # Run the migration file
    run("rails db:migrate")
    [table_name, migration_context]
  end

  private

  def self.copy_template_file(*args)
    template_path = File.join(File.expand_path("../../", __dir__), "test", "endtoend", "rails_app_template")
    FileUtils.cp(File.join(template_path, *args), File.join(@rails_root, *args))
  end

  def db_config
    YAML.load_file(File.join(@rails_root, "config", "database.yml"), aliases: true)
  end
end
