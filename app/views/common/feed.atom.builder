# frozen_string_literal: true

xml.instruct!
xml.feed "xmlns" => "http://www.w3.org/2005/Atom" do
  xml.title   truncate_single_line_raw(@title, 100)
  xml.link    "rel" => "self", "href" => url_for(:params => request.query_parameters, :only_path => false, :format => 'atom')
  xml.link    "rel" => "alternate", "href" => url_for(:params => request.query_parameters.merge(:format => nil, :key => nil), :only_path => false)
  xml.id      home_url
  xml.icon    favicon_url
  xml.updated((@items.first ? @items.first.event_datetime : Time.now).xmlschema)
  xml.author  {xml.name "#{Setting.app_title}"}
  xml.generator(:uri => Redmine::Info.url) {xml.text! Redmine::Info.app_name}
  @items.each do |item|
    xml.entry do
      url = url_for(item.event_url(:only_path => false))
      if @project == item.project
        xml.title truncate_single_line_raw(item.event_title, 100)
      else
        xml.title truncate_single_line_raw("#{item.project} - #{item.event_title}", 100)
      end
      xml.link "rel" => "alternate", "href" => url
      xml.id url
      xml.updated item.event_datetime.xmlschema
      author = item.event_author if item.respond_to?(:event_author)
      xml.author do
        xml.name(author)
        xml.email(author.mail) if author.is_a?(User) && !author.mail.blank? && !author.pref.hide_mail
      end if author
      xml.content "type" => "html" do
        xml.text! textilizable(item, :event_description, :only_path => false)
      end
    end
  end
end
