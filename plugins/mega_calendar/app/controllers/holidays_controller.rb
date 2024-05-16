class HolidaysController < ApplicationController
  unloadable
  
  before_action(:check_plugin_right)
  
  def check_plugin_right
    right = (!Setting.plugin_mega_calendar['allowed_users'].blank? && Setting.plugin_mega_calendar['allowed_users'].include?(User.current.id.to_s) ? true : false)
    unless right
      flash[:error] = translate 'no_right'
      redirect_to({:controller => :welcome})
    end
  end

  def index
    limit = 20
    offset = 0
    @new_page = 1
    @last_page = 0
    if !params[:page].blank? && params[:page].to_i >= 1
      offset = params[:page].to_i * limit
      @new_page = params[:page].to_i + 1
      @last_page = params[:page].to_i - 1
    end
    @res = Holiday.limit(limit).offset(offset)
    @pagination = (Holiday.count.to_f / 20.to_f) > 1.to_f
  end

  def new
    #DO NOTHING
  end

  def show
    @holiday = Holiday.where(:id => params[:id]).first rescue nil
    if @holiday.blank?
      redirect_to(:controller => 'holidays', :action => 'index')
    end
  end

  def create
    @holiday = Holiday.new(holiday_params)
    if @holiday.save
      redirect_to(:controller => 'holidays', :action => 'show', :id => @holiday.id)
    else
      respond_to do |format|
        format.html { render :action => 'new' }
        format.api  { render_validation_errors(@holiday) }
      end
    end
  end

  def edit
    @holiday = Holiday.find(params[:id]) rescue nil
    if @holiday.blank?
      redirect_to(:controller => 'holidays', :action => 'index')
    end
  end

  def update
    @holiday = Holiday.find(params[:holiday][:id]) rescue nil
    @holiday.assign_attributes(holiday_params)
    if @holiday.save
      redirect_to(:controller => 'holidays', :action => 'show', :id => @holiday.id)
    else
      respond_to do |format|
        format.html { render :action => 'new' }
        format.api  { render_validation_errors(@holiday) }
      end
    end
  end

  def destroy
    holiday = Holiday.where(:id => params[:id]).first rescue nil
    holiday.destroy()
    redirect_to(:controller => 'holidays', :action => 'index')
  end

  private

  def holiday_params
    params.require(:holiday).permit(:start, :end, :user_id)
  end
end
