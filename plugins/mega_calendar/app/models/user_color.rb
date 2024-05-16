class UserColor < ActiveRecord::Base
  unloadable
  belongs_to(:user)
end
