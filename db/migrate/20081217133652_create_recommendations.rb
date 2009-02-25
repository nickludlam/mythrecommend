class CreateRecommendations < ActiveRecord::Migration
  def self.up
    create_table :recommendations do |t|
      t.references :post
      t.string :title
      t.string :description
      t.string :channel
      t.string :time
      t.string :state
      t.integer :mythtv_recordid

      t.timestamps
    end
  end

  def self.down
    drop_table :recommendations
  end
end
