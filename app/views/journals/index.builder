xml.instruct!
xml.feed "xmlns" => "http://www.w3.org/2005/Atom" do
  xml.title   @title
  xml.link    "rel" => "self", "href" => url_for(:format => 'atom', :key => User.current.rss_key, :only_path => false)
  xml.link    "rel" => "alternate", "href" => home_url
  xml.id      home_url
  xml.icon    favicon_url
  xml.updated((@journals.first ? @journals.first.event_datetime : Time.now).xmlschema)
  xml.author  { xml.name "#{Setting.app_title}" }
  @journals.each do |change|
    issue = change.issue
    xml.entry do
      xml.title   "#{issue.project.name} - #{issue.tracker.name} ##{issue.id}: #{issue.subject}"
      xml.link    "rel" => "alternate", "href" => issue_url(issue)
      xml.id      issue_url(issue, :journal_id => change)
      xml.updated change.created_on.xmlschema
      xml.author do
        xml.name change.user.name
        xml.email(change.user.mail) if change.user.is_a?(User) && !change.user.mail.blank? && !change.user.pref.hide_mail
      end
      xml.content "type" => "html" do
        xml.text! '<ul>'
        details_to_strings(change.visible_details, false).each do |string|
          xml.text! '<li>' + string + '</li>'
        end
        xml.text! '</ul>'
        xml.text! textilizable(change, :notes, :only_path => false) unless change.notes.blank?
      end
    end
  end
end
