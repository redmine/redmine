module GroupUpdate
  extend ActiveSupport::Concern
  included do
    safe_attributes 'name',
                    'group_email',
                    'user_ids',
                    'custom_field_values',
                    'custom_fields',
                    :if => lambda { |group, user| user.admin? && !group.builtin? }
    validates_uniqueness_of :group_email, :case_sensitive => false
  end
end