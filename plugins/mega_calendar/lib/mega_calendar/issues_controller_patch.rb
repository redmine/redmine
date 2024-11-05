require_dependency 'issues_controller'

module MegaCalendar
  module IssuesControllerPatch
    def self.included(base)
      base.class_eval do
        before_action :update_notes_with_pricing, :only => [:new, :create, :update]
        alias_method :original_create, :create

        def create
          original_create

          unless @issue.id.blank?
            if !params[:issue][:start_date].blank? && !params[:issue][:due_date].blank? && !params[:issue][:time_begin].blank? && !params[:issue][:time_end].blank?
              tbegin = params[:issue][:start_date] + ' ' + params[:issue][:time_begin]
              tend = params[:issue][:due_date] + ' ' + params[:issue][:time_end]
              TicketTime.create({:issue_id => @issue.id, :time_begin => tbegin, :time_end => tend}) rescue nil
            end
          end
        end
    
        def update
          return unless update_issue_from_params
          # custom code
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
          # End of custom code

          attachments = params[:attachments] || params.dig(:issue, :uploads)
          if @issue.attachments_addable?
            @issue.save_attachments(attachments)
          else
            attachments = attachments.to_unsafe_hash if attachments.respond_to?(:to_unsafe_hash)
            if [Hash, Array].any? { |klass| attachments.is_a?(klass) } && attachments.any?
              flash[:warning] = l(:warning_attachments_not_saved, attachments.size)
            end
          end
      
          saved = false
          begin
            saved = save_issue_with_child_records
          rescue ActiveRecord::StaleObjectError
            @issue.detach_saved_attachments
            @conflict = true
            if params[:last_journal_id]
              @conflict_journals = @issue.journals_after(params[:last_journal_id]).to_a
              unless User.current.allowed_to?(:view_private_notes, @issue.project)
                @conflict_journals.reject!(&:private_notes?)
              end
            end
          end
      
          if saved
            render_attachment_warning_if_needed(@issue)
            unless @issue.current_journal.new_record? || params[:no_flash]
              flash[:notice] = l(:notice_successful_update)
            end
            respond_to do |format|
              format.html do
                redirect_back_or_default(
                  issue_path(@issue, previous_and_next_issue_ids_params)
                )
              end
              format.api  {render_api_ok}
            end
          else
            respond_to do |format|
              format.html {render :action => 'edit'}
              format.api  {render_validation_errors(@issue)}
            end
          end
        end
    
        def update_notes_with_pricing
          if params["issue"].present? && params["issue"]["add_pricing"].present? && params["issue"]["add_pricing"].to_i == 1
            if params["issue"]["project_id"].present?
              project = Project.find(params["issue"]["project_id"])
              if project.warrant_start.present? && project.warrant_month.present? && (((project.warrant_start + project.warrant_month.to_i.month) >= Time.now) && (project.warrant_start <= Time.now))
                if project.warrant_pricing.present?
                  pricing = project.warrant_pricing
                else
                  pricing = Setting.find_by(name: "warrant_default_pricing").try(:value)
                end
              elsif project.warrant_start.present? && project.warrant_month.present?
                if project.non_warrant_pricing.present?
                  pricing = project.non_warrant_pricing
                else
                  pricing = Setting.find_by(name: "non_warrant_default_pricing").try(:value)
                end
              end
            end
            if pricing.present?
              params["issue"]["notes"] += "\n\n"
              params["issue"]["notes"] += pricing.to_s
            else
              return unless update_issue_from_params

              @issue.errors.add(:warranty, :blank, message: l(:error_warranty_pricing_missing))
              @journals = @issue.journals.includes(:user, :details).
                  references(:user, :details).
                  reorder(:created_on, :id).to_a
              @journals.each_with_index {|j,i| j.indice = i+1}
              @journals.reject!(&:private_notes?) unless User.current.allowed_to?(:view_private_notes, @issue.project)
              Journal.preload_journals_details_custom_fields(@journals)
              @journals.select! {|journal| journal.notes? || journal.visible_details.any?}
              @journals.reverse! if User.current.wants_comments_in_reverse_order?
    
              @changesets = @issue.changesets.visible.preload(:repository, :user).to_a
              @changesets.reverse! if User.current.wants_comments_in_reverse_order?
    
              @relations = @issue.relations.select {|r| r.other_issue(@issue) && r.other_issue(@issue).visible? }
              @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
              @priorities = IssuePriority.active
              @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
              @relation = IssueRelation.new
    
              respond_to do |format|
                format.html {
                  retrieve_previous_and_next_issue_ids
                  render :template => 'issues/edit'
                }
                format.api  { render_validation_errors(@issue) }
              end
            end
          end
        end
      end
    end
  end
end
