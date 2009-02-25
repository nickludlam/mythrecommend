class Recommendation < ActiveRecord::Base

  belongs_to :post
  
  validates_presence_of :title
  validates_presence_of :channel
  validates_presence_of :time
  validates_presence_of :description
  
  named_scope :unscheduled, :conditions => { :mythtv_recordid => nil }
  named_scope :scheduled, :conditions => 'mythtv_recordid IS NOT NULL'
  
  named_scope :temporary, :conditions =>  { :state => 'temporary_schedule' }
  named_scope :permanent, :conditions =>  { :state => 'permanent_schedule' }
  named_scope :dormant, :conditions =>  { :state => 'dormant' }
  
  named_scope :recently_published, lambda {{ :conditions => ['time >= ?', 2.days.ago] }}
  named_scope :recently_created, lambda {{ :conditions => ['created_at' >= ?', 3.days.ago] }}
  
  # Acts as state machine declarations
  # acts_as_state_machine :initial => :new  # 'new' has had no interaction with MythTV yet
  # state :temporary_schedule               # 'temporary' has been scheduled with no recording yet
  # state :dormant_schedule                 # 'dormant' has had one or more recordings made, and is made dormant
  # state :permanent_schedule               # 'permanent' means the schedule will not be removed
  # 
  # event :make_temporary_schedule do
  #   transitions :from => :new, :to => :temporary_schedule
  # end
  # 
  # event :make_dormant_schedule do
  #   transitions :from => :temporary_schedule, :to => :dormant_schedule
  # end
  # 
  # event :make_permanent_schedule do
  #   transitions :from => :temporary_schedule, :to => :permanent_schedule
  #   transitions :from => :dormant_schedule, :to => :permanent_schedule
  # end
  
  def self.check_existing_schedule(schedule)
    MythTV::RecordingSchedule.find(:first, :conditions => ["title = ? AND subtitle = ?", schedule.title, schedule.subtitle])
  end
  
  # Find the program title via a fulltext search on both title and subtitle within the MythTV program database
  def program_matches_fulltext
    # We need to manually escape the select statement, as this doesn't happen for us with condition sanitization
    escaped_select = ActiveRecord::Base.send(:sanitize_sql_for_conditions,
                                             ["program.*, MATCH(title, subtitle) AGAINST (? WITH QUERY EXPANSION) AS relevancy",
                                              title])
    
    matches = MythTV::Program.find(:all,
                                   :select => escaped_select,
                                   :conditions => ["MATCH(title, subtitle) AGAINST (? WITH QUERY EXPANSION) AND starttime > ?",
                                                   title,
                                                   Time.now],
                                   :order => "relevancy DESC")
  end
  
  def program_matches_like
    MythTV::Program.find(:all,
                         :conditions => ["title LIKE ? AND starttime > ?", "#{title}", Time.now])
  end
  
  # Returns an array containing any MythTV::Recordings which have been made from this
  # Recommendation
  def recordings
    backend = Setting.connect_mythtv_backend
    recordings = backend.query_recordings({ :filter => { :recordid => /^#{mythtv_recordid}$/ }})
    backend.close
    recordings
  end
  
  # Return an instance of MythTV::RecordingSchedule if this Recommendation has a mythtv_recordid
  def recording_schedule
    MythTV::RecordingSchedule.find(:first, :conditions => { :recordid => mythtv_recordid }) if mythtv_recordid
  end
  
  # Remove any associated MythTV recording schedules, and the recordid
  def make_dormant
    attributes_to_update = {:state => 'dormant'}
    if recording_schedule 
      recording_schedule.destroy
      attributes_to_update[:mythtv_recordid] = nil
    end
    self.update_attributes(attributes_to_update)
  end
  
  def create_recording_schedule(schedule_type = "temporary_schedule")
    matches = program_matches_like
    
    if matches.length > 0
      logger.debug("We found #{matches.length} potential matches in the EPG")
      
      # Assume the top one is what we want
      new_schedule = MythTV::RecordingSchedule.new(matches.first)
      
      # weight our recordings higher than any existing schedules
      new_schedule.recpriority = 5
      
      if new_schedule.save
        logger.debug("Saved the new schedule")
        new_schedule.reload

        if new_schedule.recordid
          logger.debug("Assigned this schedule recordid #{new_schedule.recordid}")
          update_attributes({ :mythtv_recordid => new_schedule.recordid, :state => schedule_type })
        end

        logger.debug("connecting to backend")
        @backend = MythTV.connect_backend(:host => Setting.find_by_key("mythtv_hostname").value)

        begin
          logger.debug("Going to issue reschedule")
          @backend.reschedule_recordings(new_schedule.recordid)
          logger.debug("Reschedule success!")
          true
        rescue MythTV::CommunicationError => error
          logger.error("While attempting to reschedule recordings, and error was received: #{error}")
          raise
        ensure
          @backend.close
        end
      else
        logger.debug("Save failed!")
        self.errors = new_schedule.errors
      end
    end
  end
  
  def self.test
    Recommendation.unscheduled.recently_published.each do |r|
      matches = r.program_matches_like
      if matches.length > 0
        puts "Possible match for '#{r.title}'"
        puts matches.first.inspect
      end
    end
  end

end
