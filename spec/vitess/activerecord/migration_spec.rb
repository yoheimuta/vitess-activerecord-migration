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
      end
    end
  end
end
