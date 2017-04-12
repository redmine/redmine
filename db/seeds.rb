puts "Seeding..."
ActiveRecord::Base.transaction do
  user = User.last

  project = Project.create!(
    name: "Teatro",
    description: "Cloud staging server",
    homepage: "http://teatro.io",
    is_public: true,
    identifier: "teatro",
    status: 1
  )

  issue = Issue.create!(
    tracker_id: 1,
    project_id: project.id,
    subject: "Something went wrong",
    description: "We don't know what",
    due_date: nil,
    category_id: nil,
    status_id: 1,
    assigned_to_id: nil,
    priority_id: 2,
    author_id: user.id,
    start_date: 1.day.ago,
    done_ratio: 0,
    estimated_hours: nil,
    root_id: 1,
    is_private: false,
    closed_on: nil
  )

  news = News.create!(
    project_id: project.id,
    title: "We got fresh cookies!",
    summary: "Super tasty",
    description: "With chocolate bars",
    author_id: user.id
  )

  puts "Seeding done"
end
