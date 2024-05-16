class CalendarController < ApplicationController
  unloadable

  before_action(:check_plugin_right)

  def check_plugin_right
    user_id_of_api_key = '-1'
    unless params[:key].blank?
      user_id_of_api_key = User.find_by_api_key(params[:key]).id rescue '-1'
    end
    right = (!Setting.plugin_mega_calendar['allowed_users'].blank? && (Setting.plugin_mega_calendar['allowed_users'].include?(User.current.id.to_s) || Setting.plugin_mega_calendar['allowed_users'].include?(user_id_of_api_key.to_s)) ? true : false)
    unless right
      flash[:error] = translate 'no_right'
      redirect_to({:controller => :welcome})
    end
  end

  def save_filters
    uf = UserFilter.find_or_initialize_by({:filter_name => params["name"]})
    uf.filter_code = params["filter"].to_json
    uf.user_id = (params["global"] == "true" ? nil : User.current.id)
    uf.save!
    render(:plain => uf.id)
  end

  def get_saved_filters
    uf = UserFilter.find(params["id"])
    ret_val = {
      "filter" => JSON.parse(uf.filter_code), #prevent dangerous calls from eval
      "name" => uf.filter_name,
      "global" => (uf.user_id.blank? ? true : false)
    }
    render(:json => ret_val)
  end

  def destroy_filter
    UserFilter.find(params[:id]).destroy
    redirect_to(:controller => 'calendar', :action => 'index')
  end

  def query_filter(model, filters)
    condition = [""]

    condition[0] << "(" + (model == 'Holiday' ? 'holidays.user_id' : 'issues.assigned_to_id')+' IN (?) OR ' + (model == 'Holiday' ? 'holidays.user_id' : 'issues.assigned_to_id') + " IS NULL)"
    condition << Setting.plugin_mega_calendar['displayed_users']

    filters.keys.each do |x|
      filter_param = filters[x]
      filter = $mc_filters[x]
      if((filter_param[:enabled].to_s != 'true') || ((model == 'Holiday' && filter[:db_field_holiday].blank?) || (model == 'Issue' && filter[:db_field].blank?)))
        next
      end
      condition[0] << ' AND '
      if (filter[:condition].blank? && model == 'Issue') || (filter[:condition_holiday].blank? && model == 'Holiday')
        condition[0] << (model == 'Issue' ? filter[:db_field] : filter[:db_field_holiday]) + ' '
        if filter_param[:operator] == 'contains'
          condition[0] << 'IN '
        elsif filter_param[:operator] == 'not_contains'
          condition[0] << 'NOT IN '
        end
        condition[0] << '(?)'
        condition << filter_param[:value]
      else
        tmpcondition = (model == 'Issue' ? filter[:condition].gsub('##FIELD_ID##',filter[:db_field]) : filter[:condition_holiday].gsub('##FIELD_ID##',filter[:db_field_holiday])) + ' '
        count_values = tmpcondition.scan(/(?=\?)/).count
        if filter_param[:operator] == 'contains'
          tmpcondition = tmpcondition.gsub('##OPERATOR##','IN')
        elsif filter_param[:operator] == 'not_contains'
          tmpcondition = tmpcondition.gsub('##OPERATOR##','NOT IN')
        end
        condition[0] << tmpcondition
        count_values.times.each do
          condition << filter_param[:value]
        end
      end
    end
    return condition
  end

  def export
    ical = Vpim::Icalendar.create({ 'METHOD' => 'REQUEST', 'CHARSET' => 'UTF-8' })
    time_start = params['time_start']
    time_end = params['time_end']
    Issue.where(["(issues.start_date IS NOT NULL OR issues.due_date IS NOT NULL) AND ((issues.start_date >= ? AND issues.start_date <= ?) OR (issues.due_date >= ? AND issues.due_date <= ?))", time_start, time_end, time_start, time_end]).each do |issue|
      ical.add_event do |e|
        ticket_time = TicketTime.where({:issue_id => issue.id}).first rescue nil
        tbegin = ticket_time.time_begin.strftime(" %H:%M") rescue ''
        tend = ticket_time.time_end.strftime(" %H:%M") rescue ''
        if issue.start_date.blank?
          issue.start_date = issue.due_date
        end
        if issue.due_date.blank?
          issue.due_date = issue.start_date
        end
        time_start = issue.start_date.to_date.to_s + tbegin
        time_end = issue.due_date.to_date.to_s + tend
        if tbegin.blank? || tend.blank?
          if !issue.due_date.blank? && tend.blank?
            time_end = (issue.due_date + 1.day).to_date.to_s
          end
        end
        time_start = Time.parse(time_start)
        time_end = Time.parse(time_end)
        e.summary(issue.id.to_s + ' - ' + (issue.assigned_to.blank? ? '' : issue.assigned_to.firstname + " " + issue.assigned_to.lastname + ' - ') + issue.subject)
        e.dtstart(time_start)
        e.dtend(time_end)
        e.dtstamp(issue.updated_on)
        e.lastmod(issue.updated_on)
        e.created(issue.created_on)
        e.uid("RedmineMegaCalendarIssueID:"+issue.id.to_s)
        #e.sequence(seq.to_i)
        e.description(issue.description.gsub("\n\n",""))
        #unless issue.assigned_to.blank?
        #  e.organizer do |o|
        #    o.cn = issue.assigned_to.firstname + " " + issue.assigned_to.lastname
        #    o.uri = "mailto:#{issue.assigned_to.email_address.address}" rescue nil
        #  end
        #end
      end
    end
    send_data ical.encode(), filename: 'Redmine_calendar.ics'
  end

  def index
    #DO NOTHING
  end

  def form_holiday(holiday)
    ret_var = '<table>'
    ret_var << '<tr>'
    ret_var << '<td>' + (translate 'user') + '</td>'
    ret_var << '<td>' + holiday.user.name + '</td>' rescue '<td></td>'
    ret_var << '</tr>'
    ret_var << '<tr>'
    ret_var << '<td>' + (translate 'start') + '</td>'
    ret_var << '<td>' + holiday.start.to_date.to_s + '</td>' rescue '<td></td>'
    ret_var << '</tr>'
    ret_var << '<tr>'
    ret_var << '<td>' + (translate 'end') + '</td>'
    ret_var << '<td>' + holiday.end.to_date.to_s + '</td>' rescue '<td></td>'
    ret_var << '</tr>'
    ret_var << '</table>'
    return ret_var
  end
  def form_issue(issue)
    ticket_time = TicketTime.where({:issue_id => issue.id}).first rescue nil
    tbegin = ticket_time.time_begin.strftime(" %H:%M") rescue ''
    tend = ticket_time.time_end.strftime(" %H:%M") rescue ''
    ret_var = '<table>'
    ret_var << '<tr>'
    ret_var << '<td>' + (translate 'project') + '</td>'
    ret_var << '<td>' + issue.project.name + '</td>' rescue '<td></td>'
    ret_var << '</tr>'
    ret_var << '<tr>'
    ret_var << '<td>' + (translate 'status') + '</td>'
    ret_var << '<td>' + issue.status.name + '</td>' rescue '<td></td>'
    ret_var << '</tr>'
    ret_var << '<tr>'
    unless issue.assigned_to.nil?
      if issue.assigned_to.type == 'Group'
        ret_var << '<td>' + (translate 'group') + '</td>'
        ret_var << '<td>' + issue.assigned_to.lastname + '</td>' rescue '<td></td>'
      else
        ret_var << '<td>' + (translate 'user') + '</td>'
        ret_var << '<td>' + issue.assigned_to.name + '</td>' rescue '<td></td>'
      end
    end
    ret_var << '</tr>'
    ret_var << '<tr>'
    ret_var << '<td>' + (translate 'start') + '</td>'
    ret_var << '<td>' + issue.start_date.to_date.to_s + ' ' + tbegin + ' </td>' rescue '<td></td>'
    ret_var << '</tr>'
    ret_var << '<tr>'
    ret_var << '<td>' + (translate 'end') + '</td>'
    ret_var << '<td>' + issue.due_date.to_date.to_s + ' ' + tend + ' </td>' rescue '<td></td>'
    ret_var << '</tr>'
    ret_var << '</table>'
    return ret_var
  end
  def get_events
    fbegin = params[:start].to_date rescue nil
    fend = params[:end].to_date rescue nil
    fuser = params[:user].to_s == 'true'
    params[:filter] = JSON.parse(params[:filter])
    if params[:save_values].to_s == 'true'
      session[:mega_calendar_js_user_query] = fuser
      if fbegin.to_date == fbegin.to_date.beginning_of_month
        session[:mega_calendar_js_default_date] = fbegin.to_date.to_s
      else
        session[:mega_calendar_js_default_date] = (fbegin.to_date.beginning_of_month + 1.month).to_s
      end
    end
    fbegin = (Time.zone.today - 1.month) if(fbegin.blank?)
    fend = (Time.zone.today + 1.month) if(fend.blank?)
    issues_condition = query_filter('Issue', params[:filter])
    holidays_condition = query_filter('Holiday', params[:filter])
    if fuser.blank?
      holidays = Holiday.where(['((holidays.start <= ? AND holidays.end >= ?) OR (holidays.start BETWEEN ? AND ?)  OR (holidays.end BETWEEN ? AND ?))',fbegin.to_s,fend.to_s,fbegin.to_s,fend.to_s,fbegin.to_s,fend.to_s]).where(holidays_condition) rescue []
      issues = Issue.where(['((issues.start_date <= ? AND issues.due_date >= ?) OR (issues.start_date BETWEEN ? AND ?)  OR (issues.due_date BETWEEN ? AND ?))',fbegin.to_s,fend.to_s,fbegin.to_s,fend.to_s,fbegin.to_s,fend.to_s]).where(issues_condition) rescue []
      issues2 = Issue.where(['issues.start_date >= ? AND issues.due_date IS NULL',fbegin.to_s]).where(issues_condition) rescue []
      issues3 = Issue.where(['issues.start_date IS NULL AND issues.due_date <= ?',fend.to_s]).where(issues_condition) rescue []
      if Setting.plugin_mega_calendar['display_empty_dates'].to_i == 1
        issues4 = Issue.where(['issues.start_date IS NULL AND issues.due_date IS NULL AND (issues.created_on BETWEEN ? AND ?)',fbegin.to_s,fend.to_s]).where(issues_condition) rescue []
      else
        issues4 = []
      end
    else
      cur_user_ids = [User.current.id]
      cur_user_ids += User.current.groups.collect{|x| x.id} rescue []
      holidays = Holiday.where(['((holidays.start <= ? AND holidays.end >= ?) OR (holidays.start BETWEEN ? AND ?)  OR (holidays.end BETWEEN ? AND ?)) AND (holidays.user_id = ? OR holidays.user_id IS NULL)',fbegin.to_s,fend.to_s,fbegin.to_s,fend.to_s,fbegin.to_s,fend.to_s,User.current.id]).where(holidays_condition) rescue []
      issues = Issue.where(['((issues.start_date <= ? AND issues.due_date >= ?) OR (issues.start_date BETWEEN ? AND ?)  OR (issues.due_date BETWEEN ? AND ?)) AND issues.assigned_to_id IN (?)',fbegin.to_s,fend.to_s,fbegin.to_s,fend.to_s,fbegin.to_s,fend.to_s,cur_user_ids]).where(issues_condition) rescue []
      issues2 = Issue.where(['issues.start_date >= ? AND issues.due_date IS NULL AND issues.assigned_to_id IN (?)',fbegin.to_s,cur_user_ids]).where(issues_condition) rescue []
      issues3 = Issue.where(['issues.start_date IS NULL AND issues.due_date <= ? AND issues.assigned_to_id IN (?)',fend.to_s,cur_user_ids]).where(issues_condition) rescue []
      issues4 = Issue.where(['issues.start_date IS NULL AND issues.due_date IS NULL AND issues.assigned_to_id IN (?)',cur_user_ids]).where(issues_condition) rescue []
    end
    if Setting.plugin_mega_calendar['display_empty_dates'].to_i == 1
      issues4 = Issue.where(['issues.start_date IS NULL AND issues.due_date IS NULL AND issues.assigned_to_id IN (?) AND (issues.created_on BETWEEN ? AND ?)',cur_user_ids,fbegin.to_s,fend.to_s]).where(issues_condition) rescue []
    else
      issues4 = []
    end
    @events = []
    def_holiday = '#' + Setting.plugin_mega_calendar['default_holiday_color']
    def_color = '#' + Setting.plugin_mega_calendar['default_event_color']
    @events = @events + holidays.collect {|h| {:id => h.id.to_s, :controller_name => 'holiday', :title => (h.user.blank? ? '' : h.user.name + ' - ') + (translate 'holiday'), :start => h.start.to_date.to_s, :end => (h.end + 1.day).to_date.to_s, :allDay => true, :color => def_holiday, :url => Setting.plugin_mega_calendar['sub_path'] + 'holidays/show?id=' + h.id.to_s, :className => 'mega_calendar_event', :description => form_holiday(h) }}
    issues = issues + issues2 + issues3 + issues4
    issues = issues.compact.uniq
    issues.each do |i|
      ticket_time = TicketTime.where({:issue_id => i.id}).first rescue nil
      tbegin = ticket_time.time_begin.strftime(" %H:%M") rescue ''
      tend = ticket_time.time_end.strftime(" %H:%M") rescue ''
      css_classes = ['mega_calendar_event']
      if !i.status.blank? && i.status.is_closed == true
        css_classes << 'mega_calendar_event_closed'
      end
      if i.start_date.blank?
        i.start_date = i.due_date
      end
      if i.due_date.blank?
        i.due_date = i.start_date
      end
      if i.start_date.blank? && i.due_date.blank? && Setting.plugin_mega_calendar['display_empty_dates'].to_i == 1
        i.start_date = i.created_on
        i.due_date = i.created_on
      end
      color = '#' + UserColor.where({:user_id => i.assigned_to_id}).first.color_code rescue def_color
      i_event = {:id => i.id.to_s, :controller_name => 'issue', :title => i.id.to_s + ' - ' + i.subject, :start => i.start_date.to_date.to_s + tbegin, :end => i.due_date.to_date.to_s + tend, :color => color, :url => Setting.plugin_mega_calendar['sub_path'] + 'issues/' + i.id.to_s, :className => css_classes, :description => form_issue(i) }
      if tbegin.blank? || tend.blank?
        i_event[:allDay] = true
        if !i.due_date.blank? && tend.blank?
          i_event[:end] = (i.due_date + 1.day).to_date.to_s
        end
      end
      @events << i_event
    end
    render(:json => @events.to_json)
  end
  def change_holiday
    h = Holiday.find(params[:id])
    unless params[:event_end].blank?
      h.update({:start => params[:event_begin].to_date.to_s, :end => (params[:event_end].to_date - 1.day).to_date.to_s}) rescue nil
    else
      h.update({:start => params[:event_begin].to_date.to_s, :end => params[:event_begin].to_date.to_s}) rescue nil
    end
    render(:plain => "")
  end
  def change_issue
    i = Issue.find(params[:id])
    if params[:event_end].blank?
      event_end = params[:event_begin]
    else
      event_end = params[:event_end]
    end
    unless params[:event_end].include?(':')
      event_end = event_end.to_date - 1.day
    end

    begin
      i.init_journal(User.current)
      i.update({:start_date => params[:event_begin].to_date.to_s, :due_date => event_end.to_date.to_s})
    rescue nil
    end

    if params[:allDay].to_s != 'true'
      tt = TicketTime.where(:issue_id => params[:id]).first
      if tt.blank?
        tt = TicketTime.new(:issue_id => params[:id])
      end
      tt.time_begin = params[:event_begin].to_datetime.to_s
      unless params[:event_end].blank?
        tt.time_end = params[:event_end].to_datetime.to_s rescue nil
      else
        i.update({:due_date => (params[:event_begin].to_datetime + 2.hours).to_datetime.to_s})
        tt.time_end = (params[:event_begin].to_datetime + 2.hours).to_datetime.to_s
      end
      tt.save
    else
      tt = TicketTime.where(:issue_id => params[:id]).first rescue nil
      unless tt.blank?
        tt.destroy()
      end
    end
    render(:plain => "")
  end
end
