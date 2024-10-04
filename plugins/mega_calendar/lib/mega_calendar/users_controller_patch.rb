require_dependency 'users_controller'

module MegaCalendar
  module UsersControllerPatch
    def self.included(base)
      base.class_eval do

        def create
          @user = User.new(:language => Setting.default_language,
            :mail_notification => Setting.default_notification_option,
            :admin => false)
          @user.safe_attributes = params[:user]
          unless @user.auth_source_id
            @user.password              = params[:user][:password]
            @user.password_confirmation = params[:user][:password_confirmation]
          end
          @user.pref.safe_attributes = params[:pref]

          if @user.save
            # Custom code
            UserColor.create({:user_id => @user.id, :color_code => params[:user][:color]})
            # End of custom code

            Mailer.deliver_account_information(@user, @user.password) if params[:send_information]

            respond_to do |format|
              format.html do
                flash[:notice] =
                  l(:notice_user_successful_create,
                    :id => view_context.link_to(@user.login, user_path(@user)))
                if params[:continue]
                  attrs = {:generate_password => @user.generate_password}
                  redirect_to new_user_path(:user => attrs)
                else
                  redirect_to edit_user_path(@user)
                end
              end
              format.api {render :action => 'show', :status => :created, :location => user_url(@user)}
            end
          else
            @auth_sources = AuthSource.all
            # Clear password input
            @user.password = @user.password_confirmation = nil

            respond_to do |format|
              format.html {render :action => 'new'}
              format.api  {render_validation_errors(@user)}
            end
          end
        end

        def update
          is_updating_password = params[:user][:password].present? && (@user.auth_source_id.nil? || params[:user][:auth_source_id].blank?)
          if is_updating_password
            @user.password, @user.password_confirmation = params[:user][:password], params[:user][:password_confirmation]
          end
          @user.safe_attributes = params[:user]
          # Was the account actived ? (do it before User#save clears the change)
          was_activated = (@user.status_change == [User::STATUS_REGISTERED, User::STATUS_ACTIVE])
          # TODO: Similar to My#account
          @user.pref.safe_attributes = params[:pref]
      
          if @user.save
            # Custom code
            uc = UserColor.where({:user_id => @user.id}).first rescue nil
            if uc.blank?
              uc = UserColor.new({:user_id => @user.id})
            end
            uc.color_code = params[:user][:color]
            uc.save
            # End of custom code

            @user.pref.save
      
            Mailer.deliver_password_updated(@user, User.current) if is_updating_password
            if was_activated
              Mailer.deliver_account_activated(@user)
            elsif @user.active? && params[:send_information] && @user != User.current
              Mailer.deliver_account_information(@user, @user.password)
            end
      
            respond_to do |format|
              format.html do
                flash[:notice] = l(:notice_successful_update)
                redirect_to_referer_or edit_user_path(@user)
              end
              format.api  {render_api_ok}
            end
          else
            @auth_sources = AuthSource.all
            @membership ||= Member.new
            # Clear password input
            @user.password = @user.password_confirmation = nil
      
            respond_to do |format|
              format.html {render :action => :edit}
              format.api  {render_validation_errors(@user)}
            end
          end
        end
      end
    end
  end
end
