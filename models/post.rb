class Post < ActiveRecord::Base

  belongs_to :subscription
  has_many :recommendations, :dependent => :destroy
  
  validates_uniqueness_of :url
end
