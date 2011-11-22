require File.expand_path('../../test_helper', __FILE__)
require 'issue_statuses_controller'

# Re-raise errors caught by the controller.
class IssueStatusesController; def rescue_action(e) raise e end; end


class IssueStatusesControllerTest < ActionController::TestCase
  fixtures :issue_statuses, :issues

  def setup
    @controller = IssueStatusesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    User.current = nil
    @request.session[:user_id] = 1 # admin
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'index'
  end
  
  def test_index_by_anonymous_should_redirect_to_login_form
    @request.session[:user_id] = nil
    get :index
    assert_redirected_to '/login?back_url=http%3A%2F%2Ftest.host%2Fissue_statuses'
  end
  
  def test_index_by_user_should_respond_with_406
    @request.session[:user_id] = 2
    get :index
    assert_response 406
  end

  def test_new
    get :new
    assert_response :success
    assert_template 'new'
  end

  def test_create
    assert_difference 'IssueStatus.count' do
      post :create, :issue_status => {:name => 'New status'}
    end
    assert_redirected_to :action => 'index'
    status = IssueStatus.find(:first, :order => 'id DESC')
    assert_equal 'New status', status.name
  end

  def test_edit
    get :edit, :id => '3'
    assert_response :success
    assert_template 'edit'
  end

  def test_update
    put :update, :id => '3', :issue_status => {:name => 'Renamed status'}
    assert_redirected_to :action => 'index'
    status = IssueStatus.find(3)
    assert_equal 'Renamed status', status.name
  end

  def test_destroy
    Issue.delete_all("status_id = 1")

    assert_difference 'IssueStatus.count', -1 do
      delete :destroy, :id => '1'
    end
    assert_redirected_to :action => 'index'
    assert_nil IssueStatus.find_by_id(1)
  end

  def test_destroy_should_block_if_status_in_use
    assert_not_nil Issue.find_by_status_id(1)

    assert_no_difference 'IssueStatus.count' do
      delete :destroy, :id => '1'
    end
    assert_redirected_to :action => 'index'
    assert_not_nil IssueStatus.find_by_id(1)
  end

  context "on POST to :update_issue_done_ratio" do
    context "with Setting.issue_done_ratio using the issue_field" do
      setup do
        Setting.issue_done_ratio = 'issue_field'
        post :update_issue_done_ratio
      end

      should_set_the_flash_to /not updated/
      should_redirect_to('the index') { '/issue_statuses' }
    end

    context "with Setting.issue_done_ratio using the issue_status" do
      setup do
        Setting.issue_done_ratio = 'issue_status'
        post :update_issue_done_ratio
      end

      should_set_the_flash_to /Issue done ratios updated/
      should_redirect_to('the index') { '/issue_statuses' }
    end
  end

end
