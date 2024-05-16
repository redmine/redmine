require_dependency 'issues_controller'
module MegaCalendar
  module IssuesControllerPatch
    def create
      super
      unless @issue.id.blank?
        if !params[:issue][:start_date].blank? && !params[:issue][:due_date].blank? && !params[:issue][:time_begin].blank? && !params[:issue][:time_end].blank?
          tbegin = params[:issue][:start_date] + ' ' + params[:issue][:time_begin]
          tend = params[:issue][:due_date] + ' ' + params[:issue][:time_end]
          TicketTime.create({:issue_id => @issue.id, :time_begin => tbegin, :time_end => tend}) rescue nil
        end
      end
    end
    def update
      super
      unless @issue.id.blank?
        if !params[:issue][:start_date].blank? && !params[:issue][:due_date].blank? && !params[:issue][:time_begin].blank? && !params[:issue][:time_end].blank?
          tbegin = params[:issue][:start_date] + ' ' + params[:issue][:time_begin]
          tend = params[:issue][:due_date] + ' ' + params[:issue][:time_end]
          tt = TicketTime.where({:issue_id => @issue.id}).first rescue nil
          if tt.blank?
            tt = TicketTime.new({:issue_id => @issue.id})
          end
          tt.time_begin = tbegin
          tt.time_end = tend
          tt.save
        end
      end
    end
  end
end
