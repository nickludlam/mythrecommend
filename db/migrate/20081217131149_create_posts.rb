class CreatePosts < ActiveRecord::Migration
  def self.up
    create_table :posts do |t|
      t.references :subscription

      t.string :url
      t.datetime :published_at
      t.string :author

      t.timestamps
    end
  end

  def self.down
    drop_table :posts
  end
end
