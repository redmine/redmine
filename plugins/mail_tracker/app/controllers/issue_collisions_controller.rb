class IssueCollisionsController < ApplicationController
  unloadable

  def check
    available = nil
    id = params['id']
    good_id = false
    good_id = (params['id'].to_i.to_s == params['id'] ? true : false) if params['id'].present?
    assigned_to_id = params['assigned_to_id'] if params['assigned_to_id'].present?
    date_of_start = params['start_date'] if params['start_date'].present?
    start_date = date_of_start.to_date rescue nil
    date_of_due = params['due_date'] if params['due_date'].present?
    due_date = date_of_due.to_date rescue nil
    # assigned_to_id, start_date, due_date
    last_start = Issue.where(assigned_to_id: assigned_to_id).order('start_date DESC').first.try(:start_date)
    last_due_date = Issue.where(assigned_to_id: assigned_to_id).order('due_date DESC').first.try(:due_date)

    if last_start.present? && last_due_date.present?
      last_day = (last_start > last_due_date) ? last_start : last_due_date
    elsif last_start.present?
      last_day = last_start
    elsif last_due_date.present?
      last_day = last_due_date
    else

    end

    if start_date.present? && due_date.present? && last_day.present?
      diff = (due_date - start_date).to_i
      (start_date.to_datetime.to_i..last_day.to_datetime.to_i).step(1.days.to_i) { |day|
        if check_date(assigned_to_id,Time.at(day).to_date,Time.at(day+diff.days.to_i).to_date,id)
          available = day
        end
        break if available.present?
      }
    elsif start_date.present? && last_day.present?
      diff = 1
      (start_date.to_datetime.to_i..last_day.to_datetime.to_i).step(1.days.to_i) { |day|
        if check_date(assigned_to_id,Time.at(day).to_date,Time.at(day+diff.days.to_i).to_date,id)
          available = day
        end
        break if available.present?
      }
    end if assigned_to_id.present? && good_id
    output = available.present? ? Time.at(available).to_date : start_date

    render :json => output
  end

  def check_date assigned_to_id, start_date, due_date, id

    if start_date.present? && due_date.present?
      overlap_issues = Issue.where('assigned_to_id = ? AND start_date < ? AND due_date  > ? AND id != ?', assigned_to_id, due_date, start_date, id)
      # errors.add(:start_date, "user have coliding issues") if overlap_issues.present?
      # errors.add(:due_date, "time is overlaping") if overlap_issues.present?
    elsif start_date.present?
      overlap_issues = Issue.where('assigned_to_id = ? AND start_date < ? AND due_date  > ? AND id != ?', assigned_to_id, due_date, start_date, id)
      # errors.add(:start_date, "time is overlaping") if overlap_issues.present?
    elsif due_date.present?
      overlap_issues = Issue.where('assigned_to_id = ? AND start_date < ? AND due_date  > ? AND id != ?', assigned_to_id, due_date, start_date, id)
      # errors.add(:due_date, "time is overlaping") if overlap_issues.present?
    end

    overlap_issues.present? ? false : true
  end
end