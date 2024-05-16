class UserFilter < ActiveRecord::Base
  unloadable
  belongs_to(:user)
end
