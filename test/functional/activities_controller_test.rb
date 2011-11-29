require File.expand_path('../../test_helper', __FILE__)

class ActivitiesControllerTest < ActionController::TestCase
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :groups_users,
           :enabled_modules,
           :workflows,
           :auth_sources,
           :journals, :journal_details


  def test_project_index
    get :index, :id => 1, :with_subprojects => 0
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:events_by_day)

    assert_tag :tag => "h3",
               :content => /#{2.days.ago.to_date.day}/,
               :sibling => { :tag => "dl",
                 :child => { :tag => "dt",
                   :attributes => { :class => /issue-edit/ },
                   :child => { :tag => "a",
                     :content => /(#{IssueStatus.find(2).name})/,
                   }
                 }
               }
  end

  def test_project_index_with_invalid_project_id_should_respond_404
    get :index, :id => 299
    assert_response 404
  end

  def test_previous_project_index
    get :index, :id => 1, :from => 3.days.ago.to_date
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:events_by_day)

    assert_tag :tag => "h3",
               :content => /#{3.day.ago.to_date.day}/,
               :sibling => { :tag => "dl",
                 :child => { :tag => "dt",
                   :attributes => { :class => /issue/ },
                   :child => { :tag => "a",
                     :content => /#{Issue.find(1).subject}/,
                   }
                 }
               }
  end

  def test_global_index
    get :index
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:events_by_day)

    assert_tag :tag => "h3",
               :content => /#{5.day.ago.to_date.day}/,
               :sibling => { :tag => "dl",
                 :child => { :tag => "dt",
                   :attributes => { :class => /issue/ },
                   :child => { :tag => "a",
                     :content => /#{Issue.find(5).subject}/,
                   }
                 }
               }
  end

  def test_user_index
    get :index, :user_id => 2
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:events_by_day)

    assert_tag :tag => "h3",
               :content => /#{3.day.ago.to_date.day}/,
               :sibling => { :tag => "dl",
                 :child => { :tag => "dt",
                   :attributes => { :class => /issue/ },
                   :child => { :tag => "a",
                     :content => /#{Issue.find(1).subject}/,
                   }
                 }
               }
  end

  def test_user_index_with_invalid_user_id_should_respond_404
    get :index, :user_id => 299
    assert_response 404
  end

  def test_index_atom_feed
    get :index, :format => 'atom'
    assert_response :success
    assert_template 'common/feed.atom'
    assert_tag :tag => 'entry', :child => {
      :tag => 'link',
      :attributes => {:href => 'http://test.host/issues/11'}}
  end

  def test_index_atom_feed_with_one_item_type
    get :index, :format => 'atom', :show_issues => '1'
    assert_response :success
    assert_template 'common/feed.atom'
    assert_tag :tag => 'title', :content => /Issues/
  end
end
