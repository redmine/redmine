require File.dirname(__FILE__) + '/../spec_helper'

# spec_helper defines and includes module with Issue helper functions
describe ProjectEmail do
  it{ should belong_to(:project)}
  
  it{ should validate_presence_of(:email) }
  it{ should validate_presence_of(:project_id) }
  it{ should allow_value("test@example.com").for(:email) }
  it{ should allow_value("test.lastname@example.com").for(:email) }
  it{ should_not allow_value("just_some_text").for(:email) }
  it{ should_not allow_value("missing@dotcom").for(:email) }
  it{ should_not allow_value("missingatsign.com").for(:email) }
end