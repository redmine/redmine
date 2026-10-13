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

require_relative '../test_helper'

class NonWorkingDatesControllerTest < Redmine::ControllerTest
  def setup
    User.current = nil
    @request.session[:user_id] = 1 # admin
  end

  def test_index_should_list_non_working_dates_of_the_current_year_by_default
    year = User.find(1).today.year
    NonWorkingDate.create!(:date => Date.new(year, 6, 25), :name => 'Company Foundation Day')
    NonWorkingDate.create!(:date => Date.new(year - 1, 8, 13), :name => 'Summer Shutdown')

    get :index
    assert_response :success
    assert_select 'table.non_working_dates tbody tr', 1
    assert_select 'table.non_working_dates td.name', :text => 'Company Foundation Day'
    assert_select 'form[data-cm-url=?] input[name=?]', '/non_working_dates/context_menu', 'ids[]', 1
    assert_select 'span.pagination span.items', :text => '(1/2)'
    assert_select '#csv-export-options p', :text => 'Non-working dates of all years will be exported.'
    assert_select 'form.non-working-dates-year' do
      assert_select 'select[name=year] option', 2
      assert_select 'select[name=year] option[selected=selected]', :text => year.to_s
      assert_select 'li.previous a[href=?]', "/non_working_dates?year=#{year - 1}"
      assert_select 'li.next span', :text => /Next/
      assert_select 'li.next a', 0
    end
  end

  def test_index_csv_should_export_non_working_dates_of_all_years
    NonWorkingDate.create!(:date => '2021-06-25', :name => 'Company Foundation Day')
    NonWorkingDate.create!(:date => '2020-12-30')

    with_settings :date_format => '%Y-%m-%d' do
      get :index, :params => {:year => '2021', :format => 'csv'}
    end
    assert_response :success
    assert_equal 'text/csv; header=present', @response.media_type
    assert_equal ['Date,Name', '2020-12-30,', '2021-06-25,Company Foundation Day'], @response.body.lines.map(&:chomp)
  end

  def test_index_by_non_admin_should_respond_with_403
    @request.session[:user_id] = 2
    get :index
    assert_response :forbidden
  end

  def test_create
    assert_difference 'NonWorkingDate.count' do
      post :create, :params => {:non_working_date => {:date => '2026-06-25', :name => 'Company Foundation Day'}}
    end
    assert_redirected_to '/non_working_dates?year=2026'
    non_working_date = NonWorkingDate.order(:id).last
    assert_equal Date.new(2026, 6, 25), non_working_date.date
    assert_equal 'Company Foundation Day', non_working_date.name
  end

  def test_create_with_duplicate_date_should_fail
    NonWorkingDate.create!(:date => '2026-06-25')

    assert_no_difference 'NonWorkingDate.count' do
      post :create, :params => {:non_working_date => {:date => '2026-06-25'}}
    end
    assert_response :success
    assert_select_error /Date has already been taken/
  end

  def test_update
    non_working_date = NonWorkingDate.create!(:date => '2026-08-13', :name => 'Summer Shutdown')

    put :update, :params => {:id => non_working_date.id, :non_working_date => {:date => '2027-08-12', :name => 'Summer Holidays'}}
    assert_redirected_to '/non_working_dates?year=2027'
    non_working_date.reload
    assert_equal Date.new(2027, 8, 12), non_working_date.date
    assert_equal 'Summer Holidays', non_working_date.name
  end

  def test_destroy
    non_working_date = NonWorkingDate.create!(:date => '2026-06-25')

    assert_difference 'NonWorkingDate.count', -1 do
      delete :destroy, :params => {:id => non_working_date.id}
    end
    assert_redirected_to '/non_working_dates?year=2026'
  end

  def test_bulk_destroy
    first, second, third = %w(2026-08-12 2026-08-13 2026-08-14).map {|date| NonWorkingDate.create!(:date => date)}

    assert_difference 'NonWorkingDate.count', -2 do
      delete :bulk_destroy, :params => {:ids => [first.id, third.id], :back_url => '/non_working_dates?year=2026'}
    end
    assert_redirected_to '/non_working_dates?year=2026'
    assert_equal [second], NonWorkingDate.all.to_a
  end
end
