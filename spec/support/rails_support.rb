# frozen_string_literal: true

require "fileutils"

class RailsSupport
  def initialize
    @rails_root = File.join(File.expand_path("../../", __dir__), "test", "endtoend", "rails_app")
    @schema_backup_path = "#{@rails_root}/db/schema_backup.rb"
    @schema_path = "#{@rails_root}/db/schema.rb"
    @migration_files = []
  end

  def setup
    run("rails db:schema:load")

    # Save the current schema
    FileUtils.cp(@schema_path, @schema_backup_path)
  end

  def cleanup
    # Clean up database tables
    run("rake db:delete_all_tables")

    # Restore the original schema
    FileUtils.cp(@schema_backup_path, @schema_path)
    FileUtils.rm(@schema_backup_path)

    # Clean up migration files
    @migration_files.each do |f|
      FileUtils.rm(f)
    end
  end

  def run(command)
    # Change directory to @rails_root and run the Rails command
    Dir.chdir(@rails_root) do
      system("bundle exec #{command} RAILS_ENV=test", exception: true)
    end
  end
end
