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
    rails = new
    rails.create_rails_app
  end

  def create_rails_app
    FileUtils.rm_r(@rails_root, force: true)
    system("bundle exec rails new #{@rails_root} --minimal --skip-bundle --skip-test --skip-git --skip-spring --skip-listen --skip-docker --skip-asset-pipeline", exception: true)

    copy_template_file("Gemfile")
    copy_template_file("config", "database.yml")
    copy_template_file("config", "initializers", "migration.rb")
    # copy_template_file("lib", "vitess")

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

  def create_test_vitess_users(content = "", skip_migration: false)
    table_name = "test_vitess_users"
    name = "create_#{table_name}"

    migration_context = generate_migration(name, "name:string", content: content, skip_migration: skip_migration)
    [table_name, migration_context]
  end

  def generate_migration(name, field = "", content: "", skip_migration: false)
    # Create a migration file
    run("rails generate migration #{name.camelize} #{field}")

    # Get the migration file path
    migration_files = Dir.glob(File.join(@rails_root, "db", "migrate", "*_#{name}.rb"))
    migration_file = migration_files.first
    @migration_files << migration_file
    migration_context = File.basename(migration_file, ".rb")

    # Write the migration content to the migration file
    if content.present?
      original_content = File.read(migration_file)
      sub = original_content.scan("end").size == 3 ? "def change.*?end.*?end" : "def change.*?end"
      updated_content = original_content.gsub(/#{sub}/m, content)
      File.write(migration_file, updated_content)
    end

    # Run the migration file
    run("rails db:migrate") unless skip_migration
    migration_context
  end

  def start_custom_module
    copy_template_file("lib", "vitess")
    copy_template_file("config", "initializers", "app_migration.rb")
    FileUtils.rm(File.join(@rails_root, "config", "initializers", "migration.rb"))
  end

  def end_custom_module
    FileUtils.rm_r(File.join(@rails_root, "lib", "vitess"))
    FileUtils.rm(File.join(@rails_root, "config", "initializers", "app_migration.rb"))
    copy_template_file("config", "initializers", "migration.rb")
  end

  private

  def copy_template_file(*args)
    template_path = File.join(File.expand_path("../../", __dir__), "test", "endtoend", "rails_app_template")
    FileUtils.cp_r(File.join(template_path, *args), File.join(@rails_root, *args))
  end

  def db_config
    YAML.load_file(File.join(@rails_root, "config", "database.yml"), aliases: true)
  end
end
