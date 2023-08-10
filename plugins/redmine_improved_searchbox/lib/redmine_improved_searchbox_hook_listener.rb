class RedmineImprovedSearchboxHookListener < Redmine::Hook::ViewListener
	render_on :view_layouts_base_html_head, :partial => "redmine_improved_searchbox/redmine_improved_searchbox_partial"
end