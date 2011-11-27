# -*- coding: utf-8 -*-
require File.expand_path('../../test_helper', __FILE__)

class TimeEntryReportsControllerTest < ActionController::TestCase
  fixtures :projects, :enabled_modules, :roles, :members, :member_roles,
           :issues, :time_entries, :users, :trackers, :enumerations,
           :issue_statuses, :custom_fields, :custom_values

  include Redmine::I18n

  def setup
    Setting.default_language = "en"
  end

  def test_report_at_project_level
    get :report, :project_id => 'ecookbook'
    assert_response :success
    assert_template 'report'
    assert_tag :form,
      :attributes => {:action => "/projects/ecookbook/time_entries/report", :id => 'query_form'}
  end

  def test_report_all_projects
    get :report
    assert_response :success
    assert_template 'report'
    assert_tag :form,
      :attributes => {:action => "/time_entries/report", :id => 'query_form'}
  end

  def test_report_all_projects_denied
    r = Role.anonymous
    r.permissions.delete(:view_time_entries)
    r.permissions_will_change!
    r.save
    get :report
    assert_redirected_to '/login?back_url=http%3A%2F%2Ftest.host%2Ftime_entries%2Freport'
  end

  def test_report_all_projects_one_criteria
    get :report, :columns => 'week', :from => "2007-04-01", :to => "2007-04-30", :criterias => ['project']
    assert_response :success
    assert_template 'report'
    assert_not_nil assigns(:total_hours)
    assert_equal "8.65", "%.2f" % assigns(:total_hours)
  end

  def test_report_all_time
    get :report, :project_id => 1, :criterias => ['project', 'issue']
    assert_response :success
    assert_template 'report'
    assert_not_nil assigns(:total_hours)
    assert_equal "162.90", "%.2f" % assigns(:total_hours)
  end

  def test_report_all_time_by_day
    get :report, :project_id => 1, :criterias => ['project', 'issue'], :columns => 'day'
    assert_response :success
    assert_template 'report'
    assert_not_nil assigns(:total_hours)
    assert_equal "162.90", "%.2f" % assigns(:total_hours)
    assert_tag :tag => 'th', :content => '2007-03-12'
  end

  def test_report_one_criteria
    get :report, :project_id => 1, :columns => 'week', :from => "2007-04-01", :to => "2007-04-30", :criterias => ['project']
    assert_response :success
    assert_template 'report'
    assert_not_nil assigns(:total_hours)
    assert_equal "8.65", "%.2f" % assigns(:total_hours)
  end

  def test_report_two_criterias
    get :report, :project_id => 1, :columns => 'month', :from => "2007-01-01", :to => "2007-12-31", :criterias => ["member", "activity"]
    assert_response :success
    assert_template 'report'
    assert_not_nil assigns(:total_hours)
    assert_equal "162.90", "%.2f" % assigns(:total_hours)
  end

  def test_report_one_day
    get :report, :project_id => 1, :columns => 'day', :from => "2007-03-23", :to => "2007-03-23", :criterias => ["member", "activity"]
    assert_response :success
    assert_template 'report'
    assert_not_nil assigns(:total_hours)
    assert_equal "4.25", "%.2f" % assigns(:total_hours)
  end

  def test_report_at_issue_level
    get :report, :project_id => 1, :issue_id => 1, :columns => 'month', :from => "2007-01-01", :to => "2007-12-31", :criterias => ["member", "activity"]
    assert_response :success
    assert_template 'report'
    assert_not_nil assigns(:total_hours)
    assert_equal "154.25", "%.2f" % assigns(:total_hours)
    assert_tag :form,
      :attributes => {:action => "/projects/ecookbook/issues/1/time_entries/report", :id => 'query_form'}
  end

  def test_report_custom_field_criteria
    get :report, :project_id => 1, :criterias => ['project', 'cf_1', 'cf_7']
    assert_response :success
    assert_template 'report'
    assert_not_nil assigns(:total_hours)
    assert_not_nil assigns(:criterias)
    assert_equal 3, assigns(:criterias).size
    assert_equal "162.90", "%.2f" % assigns(:total_hours)
    # Custom field column
    assert_tag :tag => 'th', :content => 'Database'
    # Custom field row
    assert_tag :tag => 'td', :content => 'MySQL',
                             :sibling => { :tag => 'td', :attributes => { :class => 'hours' },
                                                         :child => { :tag => 'span', :attributes => { :class => 'hours hours-int' },
                                                                                     :content => '1' }}
    # Second custom field column
    assert_tag :tag => 'th', :content => 'Billable'
  end

  def test_report_one_criteria_no_result
    get :report, :project_id => 1, :columns => 'week', :from => "1998-04-01", :to => "1998-04-30", :criterias => ['project']
    assert_response :success
    assert_template 'report'
    assert_not_nil assigns(:total_hours)
    assert_equal "0.00", "%.2f" % assigns(:total_hours)
  end

  def test_report_all_projects_csv_export
    get :report, :columns => 'month', :from => "2007-01-01", :to => "2007-06-30",
        :criterias => ["project", "member", "activity"], :format => "csv"
    assert_response :success
    assert_equal 'text/csv', @response.content_type
    lines = @response.body.chomp.split("\n")
    # Headers
    assert_equal 'Project,Member,Activity,2007-1,2007-2,2007-3,2007-4,2007-5,2007-6,Total',
                 lines.first
    # Total row
    assert_equal 'Total,"","","","",154.25,8.65,"","",162.90', lines.last
  end

  def test_report_csv_export
    get :report, :project_id => 1, :columns => 'month',
        :from => "2007-01-01", :to => "2007-06-30",
        :criterias => ["project", "member", "activity"], :format => "csv"
    assert_response :success
    assert_equal 'text/csv', @response.content_type
    lines = @response.body.chomp.split("\n")
    # Headers
    assert_equal 'Project,Member,Activity,2007-1,2007-2,2007-3,2007-4,2007-5,2007-6,Total',
                 lines.first
    # Total row
    assert_equal 'Total,"","","","",154.25,8.65,"","",162.90', lines.last
  end

  def test_csv_big_5
    Setting.default_language = "zh-TW"
    str_utf8  = "\xe4\xb8\x80\xe6\x9c\x88"
    str_big5  = "\xa4@\xa4\xeb"
    if str_utf8.respond_to?(:force_encoding)
      str_utf8.force_encoding('UTF-8')
      str_big5.force_encoding('Big5')
    end
    user = User.find_by_id(3)
    user.firstname = str_utf8
    user.lastname  = "test-lastname"
    assert user.save
    comments = "test_csv_big_5"
    te1 = TimeEntry.create(:spent_on => '2011-11-11',
                           :hours    => 7.3,
                           :project  => Project.find(1),
                           :user     => user,
                           :activity => TimeEntryActivity.find_by_name('Design'),
                           :comments => comments)

    te2 = TimeEntry.find_by_comments(comments)
    assert_not_nil te2
    assert_equal 7.3, te2.hours
    assert_equal 3, te2.user_id

    get :report, :project_id => 1, :columns => 'day',
        :from => "2011-11-11", :to => "2011-11-11",
        :criterias => ["member"], :format => "csv"
    assert_response :success
    assert_equal 'text/csv', @response.content_type
    lines = @response.body.chomp.split("\n")    
    # Headers
    s1 = "\xa6\xa8\xad\xfb,2011-11-11,\xc1`\xadp"
    s2 = "\xc1`\xadp"
    if s1.respond_to?(:force_encoding)
      s1.force_encoding('Big5')
      s2.force_encoding('Big5')
    end
    assert_equal s1, lines.first
    # Total row
    assert_equal "#{str_big5} #{user.lastname},7.30,7.30", lines[1]
    assert_equal "#{s2},7.30,7.30", lines[2]

    str_tw = "Traditional Chinese (\xe7\xb9\x81\xe9\xab\x94\xe4\xb8\xad\xe6\x96\x87)"
    if str_tw.respond_to?(:force_encoding)
      str_tw.force_encoding('UTF-8')
    end
    assert_equal str_tw, l(:general_lang_name)
    assert_equal 'Big5', l(:general_csv_encoding)
    assert_equal ',', l(:general_csv_separator)
    assert_equal '.', l(:general_csv_decimal_separator)
  end

  def test_csv_cannot_convert_should_be_replaced_big_5
    Setting.default_language = "zh-TW"
    str_utf8  = "\xe4\xbb\xa5\xe5\x86\x85"
    if str_utf8.respond_to?(:force_encoding)
      str_utf8.force_encoding('UTF-8')
    end
    user = User.find_by_id(3)
    user.firstname = str_utf8
    user.lastname  = "test-lastname"
    assert user.save
    comments = "test_replaced"
    te1 = TimeEntry.create(:spent_on => '2011-11-11',
                           :hours    => 7.3,
                           :project  => Project.find(1),
                           :user     => user,
                           :activity => TimeEntryActivity.find_by_name('Design'),
                           :comments => comments)

    te2 = TimeEntry.find_by_comments(comments)
    assert_not_nil te2
    assert_equal 7.3, te2.hours
    assert_equal 3, te2.user_id

    get :report, :project_id => 1, :columns => 'day',
        :from => "2011-11-11", :to => "2011-11-11",
        :criterias => ["member"], :format => "csv"
    assert_response :success
    assert_equal 'text/csv', @response.content_type
    lines = @response.body.chomp.split("\n")    
    # Headers
    s1 = "\xa6\xa8\xad\xfb,2011-11-11,\xc1`\xadp"
    if s1.respond_to?(:force_encoding)
      s1.force_encoding('Big5')
    end
    assert_equal s1, lines.first
    # Total row
    s2 = ""
    if s2.respond_to?(:force_encoding)
      s2 = "\xa5H?"
      s2.force_encoding('Big5')
    elsif RUBY_PLATFORM == 'java'
      s2 = "??"
    else
      s2 = "\xa5H???"
    end
    assert_equal "#{s2} #{user.lastname},7.30,7.30", lines[1]
  end

  def test_csv_fr
    with_settings :default_language => "fr" do
      str1  = "test_csv_fr"
      user = User.find_by_id(3)
      te1 = TimeEntry.create(:spent_on => '2011-11-11',
                             :hours    => 7.3,
                             :project  => Project.find(1),
                             :user     => user,
                             :activity => TimeEntryActivity.find_by_name('Design'),
                             :comments => str1)

      te2 = TimeEntry.find_by_comments(str1)
      assert_not_nil te2
      assert_equal 7.3, te2.hours
      assert_equal 3, te2.user_id

      get :report, :project_id => 1, :columns => 'day',
          :from => "2011-11-11", :to => "2011-11-11",
          :criterias => ["member"], :format => "csv"
      assert_response :success
      assert_equal 'text/csv', @response.content_type
      lines = @response.body.chomp.split("\n")    
      # Headers
      s1 = "Membre;2011-11-11;Total"
      s2 = "Total"
      if s1.respond_to?(:force_encoding)
        s1.force_encoding('ISO-8859-1')
        s2.force_encoding('ISO-8859-1')
      end
      assert_equal s1, lines.first
      # Total row
      assert_equal "#{user.firstname} #{user.lastname};7,30;7,30", lines[1]
      assert_equal "#{s2};7,30;7,30", lines[2]

      str_fr = "Fran\xc3\xa7ais"
      if str_fr.respond_to?(:force_encoding)
        str_fr.force_encoding('UTF-8')
      end
      assert_equal str_fr, l(:general_lang_name)
      assert_equal 'ISO-8859-1', l(:general_csv_encoding)
      assert_equal ';', l(:general_csv_separator)
      assert_equal ',', l(:general_csv_decimal_separator)
    end
  end
end
