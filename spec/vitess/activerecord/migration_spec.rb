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
    end
  end
end
