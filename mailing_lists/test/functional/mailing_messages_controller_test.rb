require File.dirname(__FILE__) + '/../test_helper'
require 'mailing_messages_controller'

# Re-raise errors caught by the controller.
class MailingMessagesController; def rescue_action(e) raise e end; end

class MailingMessagesControllerTest < Test::Unit::TestCase
  def setup
    @controller = MailingMessagesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
