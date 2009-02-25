class Guardianuk < MythRecommend::SubscriptionParser

  # All MythRecommend::SubscriptionParsers must expose a create_posts() method
  def self.create_posts(subscription)
    rss = RSS::Parser.parse(subscription.url, true)
    
    count = 0
    rss.items.each do |item|
      logger.debug("Guardianuk::create_posts() Parsing URL: #{item.link}")

      # Skip^H^H^H^HDelete if we've already got it registered in the database
      if original = Post.find_by_url(item.link)
        original.destroy
      end
      
      # Skip if it's not a 'Watch this' entry
      next unless item.title.downcase =~ /watch this/ 

      post = Post.new(:subscription_id => subscription.id)
      post.url = item.link
      post.author = item.dc_creator

      logger.debug("Guardianuk::create_posts() pubDate is: #{item.pubDate}")

      post.published_at = Time.at(item.pubDate.to_i)

      if !post.save
        logger.debug("Guardianuk::create_posts() Failed to save the Post object. #{post.errors.full_messages}")
      else
        count += 1
      end
    end
    
    # Return how many new post objects have been created
    count
  end
  
  # Acts on a Post object and creates new Recommendation objects
  def self.process_post(post)
    logger.debug("Guardianuk::process_post processing #{post.url}")
  
    doc = Hpricot(open(post.url))
    content = (doc/"div#article-wrapper/p")

    # Content index
    ci = 0

    while ci < content.length
  
      r = Recommendation.new()
      r.post_id = post.id

      element_text_array = []
      
      # We should expect that titles are marked up in a <strong> tag
      break unless (content[ci]/"strong").any?
      
      content[ci].traverse_text { |x| element_text_array << x.to_s.strip unless x.to_s.strip == "" }
      # Now we should either have one or two strings in here
      
      logger.debug("Guardianuk::process_post First pass element_text_array contains '#{element_text_array.join("', '")}'")
      
      if element_text_array.length == 1
        # Advance and get the next inner_html, as we have the content in a new para
        ci += 1
        element_text_array << content[ci].inner_html.strip
      end
      
      logger.debug("Guardianuk::process_post Second pass: element_text_array contains '#{element_text_array.join("', '")}'")
      
      # Get the description
      ci += 1
      element_text_array << content[ci].inner_html.strip
      
      logger.debug("Guardianuk::process_post Third pass: element_text_array contains '#{element_text_array.join("', '")}'")
      
      # Now we should have element_text_array complete with three elements
      # Process the time and channel...
      time, channel = element_text_array[1].split(" ", 2) # Limit to one split
  
      # Get rid of any comma
      time.tr!(",", "")

      # Replace any . delimiter with :
      time.tr!(".", ":")

      # HACK/FIXME
      # peek into the next para. If it's over 64 chars, then consider it a description?
      logger.debug("Guardianuk::process_post PEEK: ci+1 IS: #{content[ci+1]}")
      
      while content[ci+1] && !(content[ci+1]/"strong").any?
        ci += 1
        element_text_array[2] += content[ci].inner_html.strip
      end
  
      title = element_text_array[0].to_s
      
      if title =~ /:/
        r.title = title.split(":")[0]
      else
        r.title = title
      end
      
      r.time = Chronic.parse(time, :now => post.published_at)
  
      if r.time.nil?
       r.time = post.published_at
      end
  
      r.channel = channel.to_s
      
      # Strip any markup from the description
      r.description = element_text_array[2].gsub(/<\/?[^>]*>/, "")
  
      if r.save
        logger.debug("Guardianuk::process_post Saved RP with id: #{r.id}")
      else
        logger.error("Guardianuk::process_post Could not save: #{r.errors.full_messages}")
        #logger.error(r.to_debug)
        #raise "ERROR"
      end
  
      ci += 1
    end
  end
end