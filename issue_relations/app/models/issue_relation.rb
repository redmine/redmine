class IssueRelation < ActiveRecord::Base
  belongs_to :issue
  belongs_to :issue_to, :class_name => 'Issue', :foreign_key => 'issue_to_id'
  
  TYPES = { "ES" => { :name => :label_rel_end_to_start, :order => 1 },
            "EE" => { :name => :label_rel_end_to_end, :order => 2 },
            "SS" => { :name => :label_rel_start_to_start, :order => 3 },
            "SE" => { :name => :label_rel_start_to_end, :order => 4 }
  }.freeze

  validates_presence_of :issue, :issue_to, :relation_type, :delay
  validates_inclusion_of :relation_type, :in => TYPES.keys
  validates_numericality_of :delay, :allow_nil => true
  
  def validate
    errors.add :issue_to_id, :activerecord_error_invalid if issue_id == issue_to_id
  end
  
end
