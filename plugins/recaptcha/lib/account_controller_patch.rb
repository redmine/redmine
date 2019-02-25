module AccountControllerRecaptchaPatch
  def self.included(base)
    base.class_eval do
      def register
        (redirect_to(home_url); return) unless Setting.self_registration? || session[:auth_source_registration]
        if request.get?
          session[:auth_source_registration] = nil
          @user = User.new(:language => current_language.to_s)
        else
          user_params = params[:user] || {}
          @user = User.new
          @user.safe_attributes = user_params
          @user.admin = false
          @user.register
          if session[:auth_source_registration]
            @user.activate
            @user.login = session[:auth_source_registration][:login]
            @user.auth_source_id = session[:auth_source_registration][:auth_source_id]
            if @user.save
              session[:auth_source_registration] = nil
              self.logged_user = @user
              flash[:notice] = l(:notice_account_activated)
              redirect_to my_account_path
            end
          else
            @user.login = params[:user][:login]
            unless user_params[:identity_url].present? && user_params[:password].blank? && user_params[:password_confirmation].blank?
              @user.password, @user.password_confirmation = user_params[:password], user_params[:password_confirmation]
            end
            skip = false

            if params[:activation_token]
              if params[:activation_token]=="student"
                skip = true
                register_automatically(@user)
              end
            end
            if !skip and verify_recaptcha(:model => @user, :private_key => Setting.plugin_recaptcha['recaptcha_private_key'])
              
              case Setting.self_registration
              when '1'
                register_by_email_activation(@user)
              when '3'
                register_automatically(@user)
              else
                register_manually_by_administrator(@user)
              end
              
              #Geppetto register (We assume the usergroup has Id=1. Check DBOSBData.java in geppetto persistence bundle)
              parameters = "username=" + @user.login + "&password=" + @user.hashed_password + "&userGroupId=1"
              geppettoRegisterURL = Rails.application.config.serversIP["geppettoIP"] + Rails.application.config.serversIP["geppettoContextPath"] + "user?" + parameters 
              begin
                geppettoRegisterContent = open(geppettoRegisterURL)
              rescue => e
                print "Error requesting url: #{geppettoRegisterURL}"
              else
                geppettoRegisterContent = JSON.parse(geppettoRegisterContent.read)
                #TODO verified content
              end
            else
              flash.delete(:recaptcha_error)
            end
          end
        end
      end
    end
  end
end

AccountController.send(:include, AccountControllerRecaptchaPatch)
