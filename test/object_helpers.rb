# frozen_string_literal: true

module ObjectHelpers
  def User.generate!(attributes={})
    @generated_user_login ||= +'user0'
    @generated_user_login.succ!
    user = User.new(attributes)
    user.login = @generated_user_login.dup if user.login.blank?
    user.mail = "#{@generated_user_login}@example.com" if user.mail.blank?
    user.firstname = "Bob" if user.firstname.blank?
    user.lastname = "Doe" if user.lastname.blank?
    yield user if block_given?
    user.save!
    user
  end

  def User.add_to_project(user, project, roles=nil)
    roles = Role.find(1) if roles.nil?
    roles = [roles] if roles.is_a?(Role)
    Member.create!(:principal => user, :project => project, :roles => roles)
  end

  def Group.generate!(attributes={})
    @generated_group_name ||= +'Group 0'
    @generated_group_name.succ!
    group = Group.new(attributes)
    group.name = @generated_group_name.dup if group.name.blank?
    yield group if block_given?
    group.save!
    group
  end

  def Project.generate!(attributes={})
    @generated_project_identifier ||= +'project-0000'
    @generated_project_identifier.succ!
    project = Project.new(attributes)
    project.name = @generated_project_identifier.dup if project.name.blank?
    project.identifier = @generated_project_identifier.dup if project.identifier.blank?
    yield project if block_given?
    project.save!
    project
  end

  def Project.generate_with_parent!(*args)
    attributes = args.last.is_a?(Hash) ? args.pop : {}
    parent = args.size > 0 ? args.first : Project.generate!

    project = Project.generate!(attributes) do |p|
      p.parent = parent
    end
    parent.reload if parent
    project
  end

  def IssueStatus.generate!(attributes={})
    @generated_status_name ||= +'Status 0'
    @generated_status_name.succ!
    status = IssueStatus.new(attributes)
    status.name = @generated_status_name.dup if status.name.blank?
    yield status if block_given?
    status.save!
    status
  end

  def Tracker.generate(attributes={})
    @generated_tracker_name ||= +'Tracker 0'
    @generated_tracker_name.succ!
    tracker = Tracker.new(attributes)
    tracker.name = @generated_tracker_name.dup if tracker.name.blank?
    tracker.default_status ||= IssueStatus.order(:position).first || IssueStatus.generate!
    yield tracker if block_given?
    tracker
  end

  def Tracker.generate!(attributes={}, &block)
    tracker = Tracker.generate(attributes, &block)
    tracker.save!
    tracker
  end

  def Role.generate!(attributes={})
    @generated_role_name ||= +'Role 0'
    @generated_role_name.succ!
    role = Role.new(attributes)
    role.name = @generated_role_name.dup if role.name.blank?
    yield role if block_given?
    role.save!
    role
  end

  # Generates an unsaved Issue
  # Doesn't send notifications by default, use :notify => true to send them
  def Issue.generate(attributes={})
    issue = Issue.new(attributes.reverse_merge(:notify => false))
    issue.project ||= Project.find(1)
    issue.tracker ||= issue.project.trackers.first
    issue.subject = 'Generated' if issue.subject.blank?
    issue.author ||= User.find(2)
    yield issue if block_given?
    issue
  end

  # Generates a saved Issue
  # Doesn't send notifications by default, use :notify => true to send them
  def Issue.generate!(attributes={}, &block)
    issue = Issue.generate(attributes, &block)
    issue.save!
    issue.reload
  end

  # Generates an issue with 2 children and a grandchild
  def Issue.generate_with_descendants!(attributes={})
    issue = Issue.generate!(attributes)
    child = Issue.generate!(:project => issue.project, :subject => 'Child1', :parent_issue_id => issue.id)
    Issue.generate!(:project => issue.project, :subject => 'Child2', :parent_issue_id => issue.id)
    Issue.generate!(:project => issue.project, :subject => 'Child11', :parent_issue_id => child.id)
    issue.reload
  end

  def Issue.generate_with_child!(attributes={})
    issue = Issue.generate!(attributes)
    Issue.generate!(:parent_issue_id => issue.id)
    issue.reload
  end

  def Journal.generate!(attributes={})
    journal = Journal.new(attributes)
    journal.user ||= User.first
    journal.journalized ||= Issue.first
    yield journal if block_given?
    journal.save!
    journal
  end

  def Version.generate!(attributes={})
    @generated_version_name ||= +'Version 0'
    @generated_version_name.succ!
    version = Version.new(attributes)
    version.name = @generated_version_name.dup if version.name.blank?
    version.project ||= Project.find(1)
    yield version if block_given?
    version.save!
    version
  end

  def TimeEntry.generate(attributes={})
    entry = TimeEntry.new(attributes)
    entry.user ||= User.find(2)
    entry.author ||= entry.user
    entry.issue ||= Issue.find(1) unless entry.project
    entry.project ||= entry.issue.project
    entry.activity ||= TimeEntryActivity.first
    entry.spent_on ||= Date.today
    entry.hours ||= 1.0
    entry
  end

  def TimeEntry.generate!(attributes={}, &block)
    entry = TimeEntry.generate(attributes, &block)
    entry.save!
    entry
  end

  def AuthSource.generate!(attributes={})
    @generated_auth_source_name ||= +'Auth 0'
    @generated_auth_source_name.succ!
    source = AuthSource.new(attributes)
    source.name = @generated_auth_source_name.dup if source.name.blank?
    yield source if block_given?
    source.save!
    source
  end

  def Board.generate!(attributes={})
    @generated_board_name ||= +'Forum 0'
    @generated_board_name.succ!
    board = Board.new(attributes)
    board.name = @generated_board_name.dup if board.name.blank?
    board.description = @generated_board_name.dup if board.description.blank?
    yield board if block_given?
    board.save!
    board
  end

  def Attachment.generate!(attributes={})
    @generated_filename ||= +'testfile0'
    @generated_filename.succ!
    attributes = attributes.dup
    attachment = Attachment.new(attributes)
    attachment.container ||= Issue.find(1)
    attachment.author ||= User.find(2)
    attachment.filename = @generated_filename.dup if attachment.filename.blank?
    attachment.save!
    attachment
  end

  def CustomField.generate!(attributes={})
    @generated_custom_field_name ||= +'Custom field 0'
    @generated_custom_field_name.succ!
    field = new(attributes)
    field.name = @generated_custom_field_name.dup if field.name.blank?
    field.field_format = 'string' if field.field_format.blank?
    yield field if block_given?
    field.save!
    field
  end

  def IssueCustomField.generate!(attributes={})
    super do |field|
      field.is_for_all = true unless attributes.key?(:is_for_all)
      field.tracker_ids = Tracker.all.ids unless attributes.key?(:tracker_ids) || attributes.key?(:trackers)
      yield field if block_given?
    end
  end

  def Changeset.generate!(attributes={})
    @generated_changeset_rev ||= +'123456'
    @generated_changeset_rev.succ!
    changeset = new(attributes)
    changeset.repository ||= Project.find(1).repository
    changeset.revision ||= @generated_changeset_rev.dup
    changeset.committed_on ||= Time.now
    yield changeset if block_given?
    changeset.save!
    changeset
  end

  def Query.generate!(attributes={})
    query = new(attributes)
    query.name = "Generated query" if query.name.blank?
    query.user ||= User.find(1)
    query.save!
    query
  end

  def Document.generate!(attributes={})
    document = new(attributes)
    document.title = "Generated document" if document.title.blank?
    document.category ||= DocumentCategory.find(1)
    document.save!
    document
  end

  def generate_import(fixture_name='import_issues.csv')
    import = IssueImport.new
    import.user_id = 2
    import.file = uploaded_test_file(fixture_name, 'text/csv')
    import.save!
    import
  end

  def generate_import_with_mapping(fixture_name='import_issues.csv')
    import = generate_import(fixture_name)

    import.settings = {
      'separator' => ";", 'wrapper' => '"', 'encoding' => "UTF-8",
      'mapping' => {'project_id' => '1', 'tracker' => '13', 'subject' => '1'}
    }
    import.save!
    import
  end

  def generate_time_entry_import(fixture_name='import_time_entries.csv')
    import = TimeEntryImport.new
    import.user_id = 2
    import.file = uploaded_test_file(fixture_name, 'text/csv')
    import.save!
    import
  end
end

module TrackerObjectHelpers
  def generate_transitions!(arg)
    if arg.delete(:clear)
      WorkflowTransition.where(:tracker_id => id).delete_all
    end
    role_id = arg.delete(:role_id) || 1

    arg.each do |old_status_id, new_status_ids|
      Array.wrap(new_status_ids).each do |new_status_id|
        WorkflowTransition.create!(
          :tracker => self,
          :role_id => role_id,
          :old_status_id => old_status_id,
          :new_status_id => new_status_id
        )
      end
    end
  end
end
Tracker.send :include, TrackerObjectHelpers

module IssueObjectHelpers
  def close!
    self.status = IssueStatus.where(:is_closed => true).first
    save!
  end

  def generate_child!(attributes={})
    Issue.generate!(attributes.merge(:parent_issue_id => self.id))
  end
end
Issue.send :include, IssueObjectHelpers
