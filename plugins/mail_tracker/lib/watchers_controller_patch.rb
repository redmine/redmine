require_dependency 'watchers_controller'
module WatchersControllerPatch
  def self.included(base)
    base.class_eval do

      def users_for_new_watcher
        scope = nil
        if params[:q].blank?
          if @project.present?
            scope = @project.principals.assignable_watchers
          elsif @projects.present? && @projects.size > 1
            scope = Principal.joins(:members).where(:members => { :project_id => @projects }).assignable_watchers.distinct
          end
        else
          scope = Principal.assignable_watchers.limit(100)
        end

        users = scope.sorted.like(params[:q]).to_a
        if @watchables && @watchables.size == 1
          watchable_object = @watchables.first
          users -= watchable_object.watcher_users
        end
        users
      end

    end
  end
end