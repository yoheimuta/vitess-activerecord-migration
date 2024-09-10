class CreateDevUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :dev_users do |t|
      t.string :name

      t.timestamps
    end
  end
end
