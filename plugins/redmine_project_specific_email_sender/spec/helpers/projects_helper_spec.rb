require File.dirname(__FILE__) + '/../spec_helper'
# spec_helper defines and includes module with Issue helper functions

describe ProjectsHelper do
  include ProjectsHelper
  
  describe "User with permissions to edit outbound_email" do
    before(:each) do
      @project = build_valid_project
      @user = build_valid_user
      @user.stub!(:allowed_to? => true)
      User.stub!(:current => @user)
    end
  
    it "should include the outbound email tab as the final tab" do
      project_settings_tabs.last[:name].should == "outbound_email"
    end
  end
  
end