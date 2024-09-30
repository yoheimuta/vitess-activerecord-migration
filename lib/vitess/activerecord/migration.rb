# frozen_string_literal: true

require_relative "migration/version"
require 'active_record'

module Vitess
  module Activerecord
    module Migration
      class Error < StandardError; end

      # Returns the default DDL strategy.
      # This method is called and set before executing the change, up, or down methods.
      #
      # If you want to use a different strategy like `direct`, override this method.
      def default_ddl_strategy
        "vitess --fast-range-rotation"
      end

      # Override exec_migration to set the default DDL strategy to vitess.
      # This method is called every time a migration is executed.
      # If you want to use a different DDL strategy, call with_ddl_strategy inside the change method or elsewhere.
      def exec_migration(connection, direction)
        @migration_direction = direction
        @using_change_method = self.respond_to?(:change)
        @migration_context = "#{self.version}_#{self.class.name.underscore}"
        with_ddl_strategy default_ddl_strategy do
          super(connection, direction)
        end
      end

      # Override the create_table method.
      # If using the Vitess strategy, wait for the completion of the CREATE TABLE statement.
      # This prevents an evaluation error from occurring if you try to execute a DDL on that table before the creation is complete.
      def create_table(table_name, **options)
        super(table_name, **options)

        # If create_table is called during revert, no additional processing is done.
        # We expect the DROP statement to be issued automatically during revert, but if execute is run here,
        # it will raise an IrreversibleMigration error, so this is to prevent that.
        return if down_migration_in_change_method?

        # If not using the Vitess strategy, do not wait for the completion of the CREATE TABLE statement.
        return unless vitess_strategy?

        wait_for_ddl
      end

      # Temporarily change the DDL strategy within the block.
      #
      # You can use this method inside the change method to change the strategy only during the execution of specific DDL statements.
      # However, note that this makes the migration irreversible, so if it’s possible to handle this by overriding the default_ddl_strategy, use that instead.
      def with_ddl_strategy(strategy)
        if enable_vitess?
          original_ddl_strategy = execute("SELECT @@ddl_strategy").first.first
          execute("SET @@ddl_strategy='#{strategy}'")
          execute("SET @@migration_context='#{@migration_context}'") unless strategy == "direct"
          begin
            yield
            wait_for_ddl unless strategy == "direct"
          ensure
            execute("SET @@ddl_strategy='#{original_ddl_strategy}'")
          end
        else
          yield
        end
      end

      private

      def vitess_strategy?
        enable_vitess? && execute("SELECT @@ddl_strategy").first.first.include?("vitess")
      end

      def down_migration_in_change_method?
        @migration_direction == :down && @using_change_method
      end

      def enable_vitess?
        version = execute("SELECT VERSION()").first.first
        version.include?("Vitess")
      end

      def wait_for_ddl
        start_time = Time.now
        timeout_seconds = 300  # 5 minutes
        interval_seconds = 2
        max_interval_seconds = 30

        @stopped_uuid ||= []

        loop do
          migrations = ActiveRecord::Base.connection.select_all("SHOW VITESS_MIGRATIONS LIKE '#{@migration_context}'")

          migrations.each do |migration|
            id = migration["id"]
            next if @stopped_uuid.include?(id)

            details = %w[migration_uuid migration_statement added_timestamp started_timestamp is_immediate_operation progress eta_seconds retries]
            detail_message = details.map { |column| "#{column}: #{migration[column]}" }.join(" | ")
            Rails.logger.info("Vitess Migration #{id} checking status, #{detail_message}")

            status = migration["migration_status"]
            if %(complete failed cancelled).include?(status)
              case status
              when "complete"
                Rails.logger.info("Vitess Migration #{id} completed successfully at #{migration["completed_timestamp"]}")
              when "failed"
                Rails.logger.error("Vitess Migration #{id} failed: #{migration["message"]} at #{migration["completed_timestamp"]}")
              when "cancelled"
                Rails.logger.warn("Vitess Migration #{id} was cancelled at #{migration["cancelled_timestamp"]}")
              end
              @stopped_uuid << id
            else
              Rails.logger.info("Vitess Migration #{id} is still #{status}")
            end
          end

          if @stopped_uuid.count == migrations.count
            Rails.logger.info("Vitess Migration all completed successfully")
            break
          end

          if Time.now - start_time > timeout_seconds
            Rails.logger.warn("Vitess Migration did not complete within #{timeout_seconds} seconds. Timing out.")
            break
          end

          Rails.logger.info("Waiting #{interval_seconds} seconds for Vitess DDL to complete...")
          sleep(interval_seconds)
          interval_seconds = [interval_seconds * 2, max_interval_seconds].min
        end
      rescue => e
        Rails.logger.error("An error occurred while waiting for Vitess DDL: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
      end
    end
  end
end
