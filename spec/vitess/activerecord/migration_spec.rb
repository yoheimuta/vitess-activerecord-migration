# frozen_string_literal: true

require_relative "../../support/rails_support"

RSpec.describe Vitess::Activerecord::Migration do
  it "has a version number" do
    expect(Vitess::Activerecord::Migration::VERSION).not_to be nil
  end

  describe "exec_migration" do
    let(:rails) { RailsSupport.new }

    before do
      rails.setup
    end

    after do
      rails.cleanup
    end

    describe "change" do
      context "when using a migration file" do
        context "when creating a table" do
          it "db:migrate and db:rollback:primary" do
            # Run the migration
            table_name, migration_context = rails.create_test_vitess_users

            # Confirm that the table has been created
            expect(ActiveRecord::Base.connection.tables).to include(table_name)

            # Confirm that Vitess has executed the migration
            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context}'")
            expect(migrations.count).to eq(1)
            migrations.each do |migration|
              expect(migration["migration_status"]).to eq("complete")
              expect(migration["is_immediate_operation"]).to eq(1)
            end

            # Revert the migration
            rails.run("rails db:rollback")

            # Confirm that the table has been deleted
            expect(ActiveRecord::Base.connection.tables).not_to include(table_name)

            # Confirm that Vitess has executed the migration
            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context}'")
            expect(migrations.count).to eq(2)
            migrations.each do |migration|
              expect(migration["migration_status"]).to eq("complete")
              expect(migration["is_immediate_operation"]).to eq(1)
            end
          end
        end

        context "when creating a table and then adding a column" do
          it "db:migrate and db:rollback:primary" do
            # Run the migration
            migration_content = <<-MIGRATION
      def change
        create_table :test_vitess_users do |t|
          t.string :name
          t.timestamps
        end

        add_column :test_vitess_users, :token, :string
      end
            MIGRATION
            table_name, migration_context = rails.create_test_vitess_users(migration_content)

            # Confirm that the table has been created
            expect(ActiveRecord::Base.connection.tables).to include(table_name)

            # Confirm that the `token` column has been added
            columns = ActiveRecord::Base.connection.columns(table_name).map(&:name)
            expect(columns).to include("token")

            # Confirm that Vitess has executed the migration
            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context}'")
            expect(migrations.count).to eq(2)
            expect(migrations.map { |m| m["is_immediate_operation"].to_i }).to eq([1, 0])
            migrations.each do |migration|
              expect(migration["migration_status"]).to eq("complete")
            end

            # Revert the migration
            rails.run("rails db:rollback")

            # Confirm that the table has been deleted
            expect(ActiveRecord::Base.connection.tables).not_to include(table_name)

            # Confirm that Vitess has executed the migration
            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context}'")
            expect(migrations.count).to eq(4)
            expect(migrations.map { |m| m["is_immediate_operation"].to_i }).to eq([1, 0, 0, 1])
            migrations.each do |migration|
              expect(migration["migration_status"]).to eq("complete")
            end
          end
        end

        context "when creating a table and then adding an index" do
          it "db:migrate and db:rollback:primary" do
            # Run the migration
            migration_content = <<-MIGRATION
      def change
        create_table :test_vitess_users do |t|
          t.string :name
          t.timestamps
        end

        add_index :test_vitess_users, :name, unique: true
      end
            MIGRATION
            table_name, migration_context = rails.create_test_vitess_users(migration_content)

            # Confirm that the table has been created
            expect(ActiveRecord::Base.connection.tables).to include(table_name)

            # Confirm that the unique index for `name` column has been added
            indexes = ActiveRecord::Base.connection.indexes(table_name)
            name_index = indexes.find { |index| index.columns == ["name"] }
            expect(name_index).not_to be_nil
            expect(name_index.unique).to be true

            # Confirm that Vitess has executed the migration
            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context}'")
            expect(migrations.count).to eq(2)
            expect(migrations.map { |m| m["is_immediate_operation"].to_i }).to eq([1, 0])
            migrations.each do |migration|
              expect(migration["migration_status"]).to eq("complete")
            end

            # Revert the migration
            rails.run("rails db:rollback")

            # Confirm that the table has been deleted
            expect(ActiveRecord::Base.connection.tables).not_to include(table_name)

            # Confirm that Vitess has executed the migration
            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context}'")
            expect(migrations.count).to eq(4)
            expect(migrations.map { |m| m["is_immediate_operation"].to_i }).to eq([1, 0, 0, 1])
            migrations.each do |migration|
              expect(migration["migration_status"]).to eq("complete")
            end
          end
        end
      end

      context "when using multiple migration files" do
        context "when creating a table and then adding an index" do
          it "db:migrate and db:rollback:primary" do
            # Run the migration
            table_name, migration_context = rails.create_test_vitess_users(skip_migration: true)
            migration_context2 = rails.generate_migration("add_name_index_to_test_vitess_users", content: <<-MIGRATION)
      def change
        add_index :test_vitess_users, :name, unique: true
      end
            MIGRATION

            # Confirm that the table has been created
            expect(ActiveRecord::Base.connection.tables).to include(table_name)

            # Confirm that the unique index for `name` column has been added
            indexes = ActiveRecord::Base.connection.indexes(table_name)
            name_index = indexes.find { |index| index.columns == ["name"] }
            expect(name_index).not_to be_nil
            expect(name_index.unique).to be true

            # Confirm that Vitess has executed the migration
            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context}'")
            expect(migrations.count).to eq(1)
            migrations.each do |migration|
              expect(migration["migration_status"]).to eq("complete")
              expect(migration["is_immediate_operation"]).to eq(1)
            end

            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context2}'")
            expect(migrations.count).to eq(1)
            migrations.each do |migration|
              expect(migration["migration_status"]).to eq("complete")
              expect(migration["is_immediate_operation"]).to eq(0)
            end

            # Revert the migration
            rails.run("rails db:rollback")

            # Confirm that the unique index for `name` column has been removed
            indexes = ActiveRecord::Base.connection.indexes(table_name)
            name_index = indexes.find { |index| index.columns == ["name"] }
            expect(name_index).to be_nil

            # Confirm that Vitess has executed the migration
            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context2}'")
            expect(migrations.count).to eq(2)
            migrations.each do |migration|
              expect(migration["migration_status"]).to eq("complete")
              expect(migration["is_immediate_operation"]).to eq(0)
            end

            # Revert the migration
            rails.run("rails db:rollback")

            # Confirm that the table has been deleted
            expect(ActiveRecord::Base.connection.tables).not_to include(table_name)

            # Confirm that Vitess has executed the migration
            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context}'")
            expect(migrations.count).to eq(2)
            migrations.each do |migration|
              expect(migration["migration_status"]).to eq("complete")
              expect(migration["is_immediate_operation"]).to eq(1)
            end
          end
        end
      end
    end

    describe "default_ddl_strategy" do
      context "when setting it to direct" do
        it "db:migrate and db:rollback:primary" do
          # Run the migration
          migration_content = <<-MIGRATION
      def default_ddl_strategy
        "direct"
      end
      def change
        create_table :test_vitess_users do |t|
          t.string :name
          t.timestamps
        end

        add_column :test_vitess_users, :token, :string
        add_index :test_vitess_users, :name, unique: true
      end
          MIGRATION
          table_name, migration_context = rails.create_test_vitess_users(migration_content)

          # Confirm that the table has been created
          expect(ActiveRecord::Base.connection.tables).to include(table_name)

          # Confirm that the `token` column has been added
          columns = ActiveRecord::Base.connection.columns(table_name).map(&:name)
          expect(columns).to include("token")

          # Confirm that the unique index for `name` column has been added
          indexes = ActiveRecord::Base.connection.indexes(table_name)
          name_index = indexes.find { |index| index.columns == ["name"] }
          expect(name_index).not_to be_nil
          expect(name_index.unique).to be true

          # Confirm that Vitess has not executed the migration
          migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context}'")
          expect(migrations.count).to eq(0)

          # Revert the migration
          rails.run("rails db:rollback")

          # Confirm that the table has been deleted
          expect(ActiveRecord::Base.connection.tables).not_to include(table_name)

          # Confirm that Vitess has not executed the migration
          migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context}'")
          expect(migrations.count).to eq(0)
        end
      end
    end

    describe "with_ddl_strategy" do
      context "when setting it to direct" do
        it "db:migrate and db:rollback:primary" do
          # Run the migration
          migration_content = <<-MIGRATION
      def change
        create_table :test_vitess_users do |t|
          t.string :name
          t.timestamps
        end

        # A subsequent index deletion depends on the index addition here.
        # This dependency results in an error due to the nature of Vitess async mechanism.
        # So you should enclose with with_ddl_strategy to execute it sequentially.
        with_ddl_strategy("direct") do
          add_index :test_vitess_users, :name, unique: true
        end
        remove_index :test_vitess_users, :name
      end
          MIGRATION
          table_name, migration_context = rails.create_test_vitess_users(migration_content)

          # Confirm that the table has been created
          expect(ActiveRecord::Base.connection.tables).to include(table_name)

          # Confirm that Vitess has executed the migration
          # But add_index has been executed directly.
          migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context}'")
          expect(migrations.count).to eq(2)
          expect(migrations.map { |m| m["is_immediate_operation"].to_i }).to eq([1, 0])
          migrations.each do |migration|
            expect(migration["migration_status"]).to eq("complete")
          end

          # Confirm that rollback is not possible because with_ddl_strategy calls execute().
          expect { rails.run("rails db:rollback") }.to raise_error RuntimeError

          # Confirm that the table has not been deleted
          expect(ActiveRecord::Base.connection.tables).to include(table_name)

          # Confirm that Vitess has not executed the migration
          migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context}'")
          expect(migrations.count).to eq(2)
        end
      end

      context "when setting it to vitess" do
        it "db:migrate and db:rollback:primary" do
          # Run the migration
          migration_content = <<-MIGRATION
      def change
        create_table :test_vitess_users do |t|
          t.string :name
          t.timestamps
        end

        # A subsequent index deletion depends on the index addition here.
        # This dependency results in an error due to the nature of Vitess async mechanism.
        # So you should enclose with with_ddl_strategy to execute it sequentially.
        with_ddl_strategy(default_ddl_strategy) do
          add_column :test_vitess_users, :token, :string
        end
        change_column :test_vitess_users, :token, :integer, null: false
      end
          MIGRATION
          table_name, migration_context = rails.create_test_vitess_users(migration_content)

          # Confirm that the table has been created
          expect(ActiveRecord::Base.connection.tables).to include(table_name)

          # Confirm that the `token` column has been added as an integer type
          token_column = ActiveRecord::Base.connection.columns("test_vitess_users").find { |c| c.name == "token" }
          expect(token_column).not_to be_nil
          expect(token_column.type).to eq(:integer)

          # Confirm that Vitess has executed the migration
          migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context}'")
          expect(migrations.count).to eq(3)
          expect(migrations.map { |m| m["is_immediate_operation"].to_i }).to eq([1, 0, 0])
          migrations.each do |migration|
            expect(migration["migration_status"]).to eq("complete")
          end

          # Confirm that rollback is not possible because with_ddl_strategy calls execute().
          expect { rails.run("rails db:rollback") }.to raise_error RuntimeError

          # Confirm that the table has not been deleted
          expect(ActiveRecord::Base.connection.tables).to include(table_name)

          # Confirm that Vitess has not executed the migration
          migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context}'")
          expect(migrations.count).to eq(3)
        end
      end
    end

    describe "up and down" do
      context "when using a migration file" do
        context "when creating a table and altering partition by range" do
          it "db:migrate and db:rollback:primary" do
            # Run the migration
            migration_content = <<-MIGRATION
      def up
        create_table :test_vitess_users do |t|
          t.date :date
          t.timestamps
        end

        execute "ALTER TABLE test_vitess_users DROP PRIMARY KEY, ADD PRIMARY KEY (id, date)"
        execute "ALTER TABLE test_vitess_users PARTITION BY RANGE (TO_DAYS(date)) (PARTITION pmax VALUES LESS THAN MAXVALUE)"
      end

      def down
        execute "ALTER TABLE test_vitess_users REMOVE PARTITIONING"
        execute "ALTER TABLE test_vitess_users DROP PRIMARY KEY, ADD PRIMARY KEY (id)"
        drop_table :test_vitess_users
      end
            MIGRATION
            table_name, migration_context = rails.create_test_vitess_users(migration_content)

            # Confirm that the table has been created
            expect(ActiveRecord::Base.connection.tables).to include(table_name)

            # Confirm that the primary key is `id`, `date`
            pk_columns = ActiveRecord::Base.connection.primary_key(table_name)
            expect(pk_columns).to eq(%w[id date])

            # Confirm that the table has been partitioned
            partition_info = ActiveRecord::Base.connection.select_all(<<-SQL).to_a
      SELECT PARTITION_NAME, PARTITION_EXPRESSION
      FROM information_schema.PARTITIONS
      WHERE TABLE_NAME = '#{table_name}'
            SQL
            expect(partition_info).not_to be_empty
            expect(partition_info.any? { |p| p["PARTITION_EXPRESSION"] == "to_days(`date`)" }).to be true
            expect(partition_info.any? { |p| p["PARTITION_NAME"] == "pmax" }).to be true

            # Confirm that Vitess has executed the migration
            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context}'")
            expect(migrations.count).to eq(3)
            expect(migrations.map { |m| m["is_immediate_operation"].to_i }).to eq([1, 0, 0])
            migrations.each do |migration|
              expect(migration["migration_status"]).to eq("complete")
            end

            # Revert the migration
            rails.run("rails db:rollback")

            # Confirm that the table has been deleted
            expect(ActiveRecord::Base.connection.tables).not_to include(table_name)

            # Confirm that Vitess has executed the migration
            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context}'")
            expect(migrations.count).to eq(6)
            expect(migrations.map { |m| m["is_immediate_operation"].to_i }).to eq([1, 0, 0, 0, 0, 1])
            migrations.each do |migration|
              expect(migration["migration_status"]).to eq("complete")
            end
          end
        end
      end
    end

    describe "override module method" do
      context "when default_ddl_strategy set --prefer-instant-ddl" do
        before do
          rails.start_custom_module
        end

        after do
          rails.end_custom_module
        end

        context "when creating a table and then adding a column" do
          it "db:migrate and db:rollback:primary" do
            # Run the migration
            migration_content = <<-MIGRATION
      def change
        create_table :test_vitess_users do |t|
          t.string :name
          t.timestamps
        end

        add_column :test_vitess_users, :token, :string
      end
            MIGRATION
            table_name, migration_context = rails.create_test_vitess_users(migration_content)

            # Confirm that the table has been created
            expect(ActiveRecord::Base.connection.tables).to include(table_name)

            # Confirm that the `token` column has been added
            columns = ActiveRecord::Base.connection.columns(table_name).map(&:name)
            expect(columns).to include("token")

            # Confirm that Vitess has executed the migration
            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context}'")
            expect(migrations.count).to eq(2)
            ## With --prefer-instant-ddl, add_column has been executed as instant operation.
            expect(migrations.map { |m| m["is_immediate_operation"].to_i }).to eq([1, 1])
            migrations.each do |migration|
              expect(migration["migration_status"]).to eq("complete")
            end

            # Revert the migration
            rails.run("rails db:rollback")

            # Confirm that the table has been deleted
            expect(ActiveRecord::Base.connection.tables).not_to include(table_name)

            # Confirm that Vitess has executed the migration
            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context}'")
            expect(migrations.count).to eq(4)
            ## With --prefer-instant-ddl, remove_column has been executed as instant operation.
            expect(migrations.map { |m| m["is_immediate_operation"].to_i }).to eq([1, 1, 1, 1])
            migrations.each do |migration|
              expect(migration["migration_status"]).to eq("complete")
            end
          end
        end
      end
    end

    describe "error handling" do
      context "when using a migration file" do
        context "when a Vitess migration fails" do
          it "db:migrate" do
            # Create a test table
            table_name, migration_context = rails.create_test_vitess_users

            # Confirm that the table has been created
            expect(ActiveRecord::Base.connection.tables).to include(table_name)

            # Confirm that Vitess has executed the migration
            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context}'")
            expect(migrations.count).to eq(1)
            migrations.each do |migration|
              expect(migration["migration_status"]).to eq("complete")
            end

            # Insert a row with a `NULL` value for `name`
            ActiveRecord::Base.connection.execute("insert into #{table_name} set created_at = now(), updated_at = now()")
            records = ActiveRecord::Base.connection.select_all("select * from #{table_name}")
            expect(records.map { |r| r["name"] }).to eq([nil])

            # Record the schema version
            schema_version_before_alter = ActiveRecord::Base.connection.schema_version

            # Change the `name` column's default to `NOT NULL`
            migration_content2 = <<-MIGRATION
        def change
          change_column :test_vitess_users, :name, :string, null: false
        end
            MIGRATION
            migration_context2 = rails.generate_migration("change_name_to_not_null", content: migration_content2, skip_migration: true)

            # Confirm that the Rails migration fails
            expect { rails.run("rails db:migrate")}.to raise_error RuntimeError

            # Confirm that the Vitess migration failed
            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context2}'")
            expect(migrations.count).to eq(1)
            migrations.each do |migration|
              expect(migration["migration_status"]).to eq("failed")
              expect(migration["message"]).to match(/failed inserting rows: Column 'name' cannot be null/)
            end

            # Confirm that the Rails schema version hasn't changed
            expect(ActiveRecord::Base.connection.schema_version).to eq(schema_version_before_alter)

            # Fix the problematic row
            ActiveRecord::Base.connection.execute("update #{table_name} set name = \"<unknown>\"")

            # Confirm that a retry of the Rails migration succeeds
            expect { rails.run("rails db:migrate")}.not_to raise_error

            # Confirm that Vitess migration retry succeeded
            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context2}'")
            expect(migrations.count).to eq(2)
            # The original migration is still failed
            migration = migrations[0]
            expect(migration["migration_status"]).to eq("failed")
            expect(migration["message"]).to match(/failed inserting rows: Column 'name' cannot be null/)
            # The retried migration should succeed
            migration = migrations[1]
            expect(migration["migration_status"]).to eq("complete")
            expect(migration["message"]).to match("")

            # Confirm that the Rails schema version is up-to-date
            expected_schema_version = migration_context2[0,14].to_i
            expect(ActiveRecord::Base.connection.schema_version).to eq(expected_schema_version)
          end
        end

        context "when a Vitess migration is cancelled" do
          it "db:migrate" do
            # Create a test table
            table_name, migration_context = rails.create_test_vitess_users

            # Confirm that the table has been created
            expect(ActiveRecord::Base.connection.tables).to include(table_name)

            # Confirm that Vitess has executed the migration
            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context}'")
            expect(migrations.count).to eq(1)
            migrations.each do |migration|
              expect(migration["migration_status"]).to eq("complete")
            end

            # Record the schema version before attempting the alter
            schema_version_before_alter = ActiveRecord::Base.connection.schema_version

            # Generate migration that alters the table
            migration_content2 = <<-MIGRATION
        def default_ddl_strategy
          # Postpone completion so we can cancel it for testing
          "vitess --postpone-completion"
        end

        def change
          add_column :test_vitess_users, :email, :string
        end
            MIGRATION
            migration_context2 = rails.generate_migration("add_email_to_#{table_name}", content: migration_content2, skip_migration: true)

            # Start background thread to monitor the resulting Vitess migrations and cancel them
            Thread.new do
              loop do
                migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context2}'")
                puts "Migration monitor: Found #{migrations.count} migrations for #{migration_context2}"
                if migrations.count > 0
                  migrations.each do |migration|
                    puts "Migration monitor: Cancelling migration #{migration['migration_uuid']}"
                    ActiveRecord::Base.connection.execute("ALTER VITESS_MIGRATION '#{migration['migration_uuid']}' cancel")
                  end
                  break
                end
                sleep 0.5
              end
            rescue => e
              puts "Migration monitor: error: #{e.message}"
            end

            # Confirm that the Rails migration exits with an error
            expect { rails.run("rails db:migrate")}.to raise_error RuntimeError

            # Confirm that the Vitess migration was cancelled
            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context2}'")
            expect(migrations.count).to eq(1)
            migrations.each do |migration|
              expect(migration["migration_status"]).to eq("cancelled")
              expect(migration["message"]).to match(/CANCEL issued by user/)
            end

            # Confirm that the Rails schema version hasn't changed
            expect(ActiveRecord::Base.connection.schema_version).to eq(schema_version_before_alter)

            # Start background thread to monitor the resulting Vitess migrations and complete them
            Thread.new do
              loop do
                migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS WHERE migration_context = \"#{migration_context2}\" and migration_status != \"cancelled\"")
                puts "Migration monitor: Found #{migrations.count} non-cancelled migrations for #{migration_context2}"
                if migrations.count > 0
                  migrations.each do |migration|
                    puts "Migration monitor: Completing migration #{migration['migration_uuid']}"
                    ActiveRecord::Base.connection.execute("ALTER VITESS_MIGRATION '#{migration['migration_uuid']}' complete")
                  end
                  break
                end
                sleep 0.5
              end
            rescue => e
              puts "Migration monitor: error: #{e.message}"
            end

            # Confirm that a retry succeeds
            expect { rails.run("rails db:migrate")}.not_to raise_error

            # Confirm that the Vitess migration succeeded
            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context2}'")
            expect(migrations.count).to eq(2)
            migration = migrations[0]
            expect(migration["migration_status"]).to eq("cancelled")
            expect(migration["message"]).to match(/CANCEL issued by user/)
            migration = migrations[1]
            expect(migration["migration_status"]).to eq("complete")
            expect(migration["message"]).to match("")

            # Confirm that the Rails schema version is up-to-date
            expected_schema_version = migration_context2[0,14].to_i
            expect(ActiveRecord::Base.connection.schema_version).to eq(expected_schema_version)
          end
        end

        context "when a Vitess migration times out" do
          it "db:migrate exits with an error" do
            # Create a test table
            table_name, migration_context = rails.create_test_vitess_users

            # Confirm that the table has been created
            expect(ActiveRecord::Base.connection.tables).to include(table_name)

            # Confirm that Vitess has executed the migration
            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context}'")
            expect(migrations.count).to eq(1)
            migrations.each do |migration|
              expect(migration["migration_status"]).to eq("complete")
            end

            # Record the schema version before attempting the alter
            schema_version_before_alter = ActiveRecord::Base.connection.schema_version

            # Generate migration that alters the table
            migration_content2 = <<-MIGRATION
        def default_ddl_strategy
          # Postpone completion so we can simulate a long-running migration and test timeouts
          "vitess --postpone-completion"
        end

        def wait_timeout_seconds
          # Reduce timeout for test to trigger a timed out migration
          3
        end

        def change
          add_column :test_vitess_users, :email, :string
        end
            MIGRATION
            migration_context2 = rails.generate_migration("add_email_to_#{table_name}", content: migration_content2, skip_migration: true)

            # Confirm that the Rails migration exits with an error
            expect { rails.run("rails db:migrate")}.to raise_error RuntimeError

            # Confirm that the Vitess migration was still running
            migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{migration_context2}'")
            expect(migrations.count).to eq(1)
            migrations.each do |migration|
              expect(migration["migration_status"]).to eq("running")
            end

            # Confirm that the Rails schema version hasn't changed
            expect(ActiveRecord::Base.connection.schema_version).to eq(schema_version_before_alter)

            # Cancel Vitess migrations to avoid blocking other tests
            migrations.each do |migration|
              ActiveRecord::Base.connection.execute("ALTER VITESS_MIGRATION '#{migration['migration_uuid']}' cancel")
            end
          end
        end
      end
    end
  end
end
