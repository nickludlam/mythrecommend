class SettingsController < ApplicationController

  def index
    @settings_map = {}
    @settings = Setting.find(:all)
    
    @settings.each do |s|
      @settings_map[s.key] = s.value
    end

    if request.post?
      # Try and update them
      @settings_map.each_pair do |k,v|
        new_value = params[k]
        if new_value != v
          @settings.find { |s| s.key = k }.update_attribute(:value, new_value)
          logger.debug("#{k} is now #{new_value} (was #{v})")
        else
          logger.debug()
        end
      end
    end
    
    respond_to do |format|
      format.html # index.html.erb
    end
  end

end
