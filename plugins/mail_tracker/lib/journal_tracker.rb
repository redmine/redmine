module JournalTracker
  extend ActiveSupport::Concern
  included do
    scope :visible, lambda { |*args|
      user = args.shift || User.current
      joins(issue: :project).
      joins("left join watchers wa on wa.watchable_id = issues.id")
        .where(Issue.visible_condition(user, *args))
        .where("(#{Journal.table_name}.private_notes = ? OR (#{Project.allowed_to_condition(user, :view_private_notes, *args)}))", false)
        .distinct
    }
  end
end