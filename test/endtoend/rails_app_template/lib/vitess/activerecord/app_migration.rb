module Vitess
  module Activerecord
    module AppMigration
      def default_ddl_strategy
        "vitess --prefer-instant-ddl --fast-range-rotation"  # Set your common default DDL strategy here
      end
    end
  end
end