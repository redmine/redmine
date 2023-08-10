require File.dirname(__FILE__) + '/../spec_helper'
# spec_helper defines and includes module with Issue helper functions

describe Mailer, "when issue related emails have a project specific email address" do
  before(:each) do
    # Project specific email will be "project@example.com"
    @issue = build_issue_with_required_associations
    @issue.save
    # Create a journal
    @journal = Journal.new(:notes => "Some basic notes", :user => @issue.author, :journalized_type => "Issue", :journalized_id => @issue.id)
    @journal.save
    # Create a document
    category = Enumeration.create(:opt => "IPRI", :name => "zzz")
    @document = Document.create(:title => "Test Doc Title", :description => "Doc Description", :project => @issue.project, :category_id => category.id)
    @document.category = category
    # Stub the document's project to return an email for recipients -- not concerned with how the value is received for these tests
    @document.project.stub!(:recipients => "some_email@example.com")
    # Clear the deliveries
    ActionMailer::Base.deliveries.clear
  end

  it "should have a correct email" do
    @issue.project.project_email.email.should == "project@example.com"
  end
  
  describe "'issue added' email is sent" do
    it "should use the project's email address as the sender" do
      Mailer.deliver_issue_add(@issue)
      mail = ActionMailer::Base.deliveries.last
      mail.from[0].should == @issue.project.email
    end
  end
  
  describe "'issue edit' email is sent" do
    it "should use the project's email address as the sender" do
      Mailer.deliver_issue_edit(@journal)
      mail = ActionMailer::Base.deliveries.last
      mail.from[0].should == @journal.project.email
    end
  end

  describe "'document added' email is sent" do
    it "should use the project's email address as the sender" do
      Mailer.deliver_document_added(@document)
      mail = ActionMailer::Base.deliveries.last
      mail.from[0].should == @document.project.email
    end
  end
  
  describe "'attachments added' email is sent" do
    it "should use the project's email address as the sender" do
      # create an attachment to pass to the mailer
      attachment = Attachment.new(:downloads => 0, :content_type => "text/plain", :disk_filename => "testtext/plain", :container_type => "Document",
                                  :filesize => 28, :filename => "document.txt", :author => @issue.author, :container => @document)
      attachments = [attachment]
      Mailer.deliver_attachments_added(attachments)
      mail = ActionMailer::Base.deliveries.last
      mail.from[0].should == @document.project.email
    end
  end

  describe "'news added' email is sent" do
    it "should use the project's email address as the sender" do
      news = News.new(:project => @issue.project, :author => @issue.author, :title => "Test News Title", :description => "Some Description")
      news.save
      news.project.stub!(:recipients => "test@example.com")
      Mailer.deliver_news_added(news)
      mail = ActionMailer::Base.deliveries.last
      mail.from[0].should == news.project.email
    end
  end
  
  describe "'message posted' email is sent" do
    it "should use the project's email address as the sender" do
      board = Board.create(:name => "Test Board", :description => "Board details", :project => @issue.project)
      board.should_not be_nil
      message = Message.new(:subject => "test post", :content => "test content", :author => @issue.author, :board => board)
      message.save.should be_true
      Mailer.deliver_message_posted(message, "test@example.com")
      mail = ActionMailer::Base.deliveries.last
      mail.from[0].should == message.board.project.email
    end
  end
end

describe Mailer, "when issue related emails do not have a project specific email address" do
  before(:each) do
    @default_sender = Setting.mail_from
    @issue = build_issue_with_required_associations
    @issue.project.project_email = nil
    @issue.save
    # Create a journal for this
    @journal = Journal.new(:notes => "Some basic notes", :user => @issue.author, :journalized_type => "Issue", :journalized_id => @issue.id)
    @journal.save
    # Create a document
    category = Enumeration.create(:opt => "IPRI", :name => "zzz")
    @document = Document.create(:title => "Test Doc Title", :description => "Doc Description", :project => @issue.project, :category_id => category.id)
    @document.category = category
    # Stub the document's project to return an email for recipients -- not concerned with how the value is received for these tests
    @document.project.stub!(:recipients => "some_email@example.com")
    ActionMailer::Base.deliveries.clear
  end
  
  describe "'issue added' email is sent" do
    it "should use the default sender email address" do
      Mailer.deliver_issue_add(@issue)
      mail = ActionMailer::Base.deliveries.last
      mail.from[0].should == @default_sender
    end
  end
  
  describe "'issue edit' email is sent" do
    it "should use the default sender email address" do
      Mailer.deliver_issue_edit(@journal)
      mail = ActionMailer::Base.deliveries.last
      mail.from[0].should == @default_sender
    end
  end
  
  describe "'document added' email is sent" do
    it "should use the default sender email address" do
      Mailer.deliver_document_added(@document)
      mail = ActionMailer::Base.deliveries.last
      mail.from[0].should == @default_sender
    end
  end
  
  describe "'attachments added' email is sent" do
    it "should use the default sender email address" do
      # create an attachment to pass to the mailer
      attachment = Attachment.new(:downloads => 0, :content_type => "text/plain", :disk_filename => "testtext/plain", :container_type => "Document",
                                  :filesize => 28, :filename => "document.txt", :author => @issue.author, :container => @document)
      attachments = [attachment]
      Mailer.deliver_attachments_added(attachments)
      mail = ActionMailer::Base.deliveries.last
      mail.from[0].should == @default_sender
    end
  end
  
  describe "'news added' email is sent" do
    it "should use the default sender email address" do
      news = News.new(:project => @issue.project, :author => @issue.author, :title => "Test News Title", :description => "Some Description")
      news.save
      news.project.stub!(:recipients => "test@example.com")
      Mailer.deliver_news_added(news)
      mail = ActionMailer::Base.deliveries.last
      mail.from[0].should == @default_sender
    end
  end
  
  describe "'message posted' email is sent" do
    it "should use the default sender email address" do
      board = Board.create(:name => "Test Board", :description => "Board details", :project => @issue.project)
      board.should_not be_nil
      message = Message.new(:subject => "test post", :content => "test content", :author => @issue.author, :board => board)
      message.save.should be_true
      Mailer.deliver_message_posted(message, "test@example.com")
      mail = ActionMailer::Base.deliveries.last
      mail.from[0].should == @default_sender
    end
  end
end