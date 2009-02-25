class Setting < ActiveRecord::Base

  validates_presence_of :key
  validates_uniqueness_of :key
  
  # We need these columns to be indexed as fulltext to allow proper searching
  REQUIRED_FULLTEXT_COLUMNS = ['title', 'subtitle']
  
  def self.has_connection_details?
    self.find_by_key('mythtv_hostname') && self.find_by_key('mythtv_password')
  end
  
  def self.connect_mythtv_database
    MythTV.connect_database(:host              => Setting.find_by_key('mythtv_hostname').value,
                            :database_password => Setting.find_by_key('mythtv_password').value)
  end
  
  def self.connect_mythtv_backend
    MythTV.connect_backend(:host => Setting.find_by_key('mythtv_hostname').value)
  end
  
  # Fulltext index methods: These may or may not be required depending on how accurate the
  # references to EPG events are. A 'LIKE' match may be sufficient, but these methods are here
  # in case it would be easier to make a ranked FULLTEXT match
  
  # Returns true when the columns listed in REQUIRED_FULLTEXT_COLUMNS are indexed as FULLTEXT
  def self.test_fulltext_index
    program_index_hash = MythTV::Program.connection.execute('SHOW KEYS FROM program').all_hashes
    
    # We need to find if there are two rows which match
    matching_keys = program_index_hash.find_all do |row|
      row['Index_type'] == 'FULLTEXT' && REQUIRED_FULLTEXT_COLUMNS.include?(row['Column_name'])
    end
    
    # This ensures that the index we've matched on spans the columns we want in REQUIRED_FULLTEXT_COLUMNS
    matching_keys.length >= 2 && matching_keys.map { |x| x['Key_name'] }.uniq.length >= 1
  end

  # Create the fulltext index, and return true upon success. Return false if an exception was raised
  def self.create_fulltext_index
    begin
      MythTV::Program.connection.execute('CREATE FULLTEXT INDEX ft_title_subtitle ON program (title, subtitle)')
      true
    rescue
      false
    end
  end
  
end
