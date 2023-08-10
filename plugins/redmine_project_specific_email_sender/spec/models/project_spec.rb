require File.dirname(__FILE__) + '/../spec_helper'

# spec_helper defines and includes module with Issue helper functions
describe Project do
  before(:each) do
    @project = build_valid_project
    @email_address = "project@example.com"
  end
  
  it{ should have_one(:project_email) }
  
  describe ".email" do
    it "should return the associated ProjectEmail if one exists" do
      project_email = ProjectEmail.create(:email => @email_address)
      @project.project_email = project_email
      @project.email.should == project_email.email
    end
    
    it "should return the Setting.mail_from if no associated ProjectEmail exists" do
      @project.email.should == Setting.mail_from
    end
  end
  
  describe ".email=" do
    it "should create a new email if one does not exist" do
      @project.project_email.should be_nil
      @project.email = @email_address
      @project.project_email.should be_a(ProjectEmail)
      @project.project_email.email.should == @email_address
    end
    
    it "should replace the current email with the new value" do
      old_email = "old_email@example.com"
      @project.create_project_email(:email => old_email)
      @project.email = @email_address
      @project.project_email.email.should == @email_address
    end
  end
end