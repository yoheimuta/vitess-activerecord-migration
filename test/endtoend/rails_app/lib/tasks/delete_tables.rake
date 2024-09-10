namespace :db do
  desc 'Delete all tables from the test database'
  task delete_all_tables: :environment do
    # Deleting all tables
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{table}")
    end

    puts "All tables have been deleted from the #{Rails.env} database."
  end
end
