class UpdateOrphanedJournalUpdatedByIdToAnonymous < ActiveRecord::Migration[7.2]
  def up
    # Don't use `User.anonymous` here because it creates a new anonymous
    # user if one doesn't exist yet.
    anonymous_user_id = AnonymousUser.unscoped.pick(:id)
    # The absence of an anonymous user implies a fresh installation.
    return if anonymous_user_id.nil?

    Journal.joins('LEFT JOIN users ON users.id = journals.updated_by_id')
           .where.not(updated_by_id: nil)
           .where(users: { id: nil })
           .update_all(updated_by_id: anonymous_user_id)
  end

  def down
    # no-op
  end
end
