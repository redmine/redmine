# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class NonWorkingDatesController < ApplicationController
  layout 'admin'
  self.main_menu = false
  menu_item :settings

  before_action :require_admin
  before_action :find_non_working_date, :only => [:edit, :update, :destroy]

  def index
    @year = params[:year].to_i if /\A\d{4}\z/.match?(params[:year].to_s)
    @year ||= User.current.today.year
    years = NonWorkingDate.years
    @years = (years | [@year, User.current.today.year]).sort
    @previous_year = @year - 1 if years.any? {|year| year < @year}
    @next_year = @year + 1 if years.any? {|year| year > @year}
    @non_working_dates = NonWorkingDate.in_year(@year).sorted.to_a
    @non_working_date_count = NonWorkingDate.count
  end

  def new
    @non_working_date = NonWorkingDate.new
  end

  def create
    @non_working_date = NonWorkingDate.new
    @non_working_date.safe_attributes = params[:non_working_date]
    if @non_working_date.save
      flash[:notice] = l(:notice_successful_create)
      if params[:continue]
        redirect_to new_non_working_date_path
      else
        redirect_to non_working_dates_path(:year => @non_working_date.date.year)
      end
    else
      render :action => 'new'
    end
  end

  def edit
  end

  def update
    @non_working_date.safe_attributes = params[:non_working_date]
    if @non_working_date.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to non_working_dates_path(:year => @non_working_date.date.year)
    else
      render :action => 'edit'
    end
  end

  def destroy
    @non_working_date.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to non_working_dates_path(:year => @non_working_date.date.year)
  end

  def bulk_destroy
    NonWorkingDate.where(:id => params[:ids]).delete_all
    NonWorkingDate.clear_dates_cache
    flash[:notice] = l(:notice_successful_delete)
    redirect_back_or_default non_working_dates_path
  end

  private

  def find_non_working_date
    @non_working_date = NonWorkingDate.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
