class Subscription < ActiveRecord::Base

  has_many :posts

  # Pull out a list of parsers from lib/parser_modules/
  def self.available_parsers
    Dir["#{RAILS_ROOT}/lib/parser_modules/*_parser.rb"].collect do |p|
      File.basename(p).gsub("_parser.rb", "")
    end
  end
  
  # Loop through each Subscription and call the fetch method, causing it to process
  # any new Posts and Recommendations
  def self.fetch_all
    self.find(:all).each do |sub|
      sub.fetch
    end
  end
  
  def fetch
    require "#{self.parser}_parser"
    parser_class = self.parser.classify.constantize
    
    # Fetch the new posts, and process them
    parser_class.fetch_posts(self).each do |post|
      parser_class.process_post(post)
    end
  end
  

end
