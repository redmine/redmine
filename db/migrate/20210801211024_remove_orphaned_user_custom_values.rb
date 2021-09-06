class RemoveOrphanedUserCustomValues < ActiveRecord::Migration[6.1]
  def up
    user_custom_field_ids = CustomField.where(field_format: 'user').pluck(:id)
    if user_custom_field_ids.any?
      user_ids = Principal.pluck(:id)
      CustomValue.
        where(custom_field_id: user_custom_field_ids).
        where.not(value: [nil, ''] + user_ids).
        delete_all
    end
  end
end
