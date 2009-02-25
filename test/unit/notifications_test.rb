require 'test_helper'

class NotificationsTest < ActionMailer::TestCase
  test "summary" do
    @expected.subject = 'Notifications#summary'
    @expected.body    = read_fixture('summary')
    @expected.date    = Time.now

    assert_equal @expected.encoded, Notifications.create_summary(@expected.date).encoded
  end

end
