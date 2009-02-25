class CreateSubscriptions < ActiveRecord::Migration
  def self.up
    create_table :subscriptions do |t|
      t.string :name
      t.string :url
      t.string :parser
    end
  end

  def self.down
    drop_table :subscriptions
  end
end
