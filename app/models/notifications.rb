class Notifications < ActionMailer::Base
  def summary(recommendations_with_new_schedules, recommendations_with_existing_schedules,
              recommendation_with_no_matches, recommendations_with_recordings,
              recommendations_awaiting_recording, sent_at = Time.now)
    subject    'mythRecommend summary'
    from       'mythRecommend@recoil.org'
    recipients Setting.find(:all, :conditions => { :key => "summary_email_recipient" }).collect { |s| s.value }
    sent_on    sent_at

    #content_type "text/html"

    body :recommendations_with_new_schedules => recommendations_with_new_schedules,
         :recommendations_with_existing_schedules => recommendations_with_existing_schedules,
         :recommendation_with_no_matches => recommendation_with_no_matches,
         :recommendations_with_recordings => recommendations_with_recordings,
         :recommendations_awaiting_recording => recommendations_awaiting_recording
  end
  
end
