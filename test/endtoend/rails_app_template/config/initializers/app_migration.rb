require 'vitess/activerecord/app_migration'

ActiveRecord::Migration.prepend(Vitess::Activerecord::Migration)
ActiveRecord::Migration.prepend(Vitess::Activerecord::AppMigration)
