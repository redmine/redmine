require File.dirname(__FILE__) + '/../test_helper'
require 'mailing_lists_controller'

# Re-raise errors caught by the controller.
class MailingListsController; def rescue_action(e) raise e end; end

class MailingListsControllerTest < Test::Unit::TestCase
  fixtures :mailing_lists

  def setup
    @controller = MailingListsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @first_id = mailing_lists(:first).id
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'list'
  end

  def test_list
    get :list

    assert_response :success
    assert_template 'list'

    assert_not_nil assigns(:mailing_lists)
  end

  def test_show
    get :show, :id => @first_id

    assert_response :success
    assert_template 'show'

    assert_not_nil assigns(:mailing_list)
    assert assigns(:mailing_list).valid?
  end

  def test_new
    get :new

    assert_response :success
    assert_template 'new'

    assert_not_nil assigns(:mailing_list)
  end

  def test_create
    num_mailing_lists = MailingList.count

    post :create, :mailing_list => {}

    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_equal num_mailing_lists + 1, MailingList.count
  end

  def test_edit
    get :edit, :id => @first_id

    assert_response :success
    assert_template 'edit'

    assert_not_nil assigns(:mailing_list)
    assert assigns(:mailing_list).valid?
  end

  def test_update
    post :update, :id => @first_id
    assert_response :redirect
    assert_redirected_to :action => 'show', :id => @first_id
  end

  def test_destroy
    assert_nothing_raised {
      MailingList.find(@first_id)
    }

    post :destroy, :id => @first_id
    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_raise(ActiveRecord::RecordNotFound) {
      MailingList.find(@first_id)
    }
  end
end
