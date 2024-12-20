module IssuesControllerPatch
  def self.included(base)
    base.class_eval do
      def new
        respond_to do |format|
          format.html {render :action => 'new', :layout => !request.xhr?}
          format.js { render 'issues/new.js.erb', :layout => false }
        end
      end
    end
  end
end
