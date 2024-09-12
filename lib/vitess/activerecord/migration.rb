# frozen_string_literal: true

require_relative "migration/version"
require 'active_record'

module Vitess
  # TODO: Rename it to ActiveRecord
  module Activerecord
    module Migration
      class Error < StandardError; end
      # デフォルトの DDL strategy を返す。
      # このメソッドは、change, up, down メソッドの実行前に呼び出されセットされる。
      #
      # `direct` など別の strategy を使いたい場合は、このメソッドをオーバーライドすること。
      def default_ddl_strategy
        "vitess --prefer-instant-ddl --fast-range-rotation"
      end

      # DDL strategy に vitess をデフォルトで設定するために exec_migration をオーバーライドする。
      # このメソッドは、migration を実行するたびに呼び出される。
      # 別の DDL strategy を使いたい場合は、change メソッド内などで with_ddl_strategy を呼び出すこと。
      def exec_migration(connection, direction)
        @migration_direction = direction
        @using_change_method = self.respond_to?(:change)
        @migration_context = "#{self.version}_#{self.class.name.underscore}"
        with_ddl_strategy default_ddl_strategy do
          super(connection, direction)
        end
      end

      # create_table メソッドをオーバーライドする。
      # vitess strategy を使っている場合、CREATE TABLE 文の実行完了を待つ。
      # テーブルの作成完了前にそのテーブルに対する DDL を実行しようとして、評価エラーになるのを防ぐため。
      def create_table(table_name, **options)
        super(table_name, **options)

        # revert で create_table が呼ばれた場合は、追加の処理を行わない。
        # revert 時には DROP 文が自動で発行されるのを期待するところ、ここで execute が実行されると
        # IrreversibleMigration エラーが発生してしまうのでそれを防ぐための対応。
        return if down_migration_in_change_method?

        # vitess strategy を使っていない場合は、CREATE TABLE 文の実行完了を待たない。
        return unless vitess_strategy?

        wait_for_ddl
      end

      # ブロック内で一時的に DDL strategy を変更する。
      #
      # このメソッドを change メソッド内などで使うことで、特定の DDL 文の実行中だけ strategy を変更することができる。
      # ただし、そうすると revert できなくなるので、revert 可能な default_ddl_strategy の上書きで対応できる場合はそちらを使うこと。
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
