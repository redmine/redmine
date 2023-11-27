class RemoveAutologinTokens < ActiveRecord::Migration[4.2]
  def up
    say_with_time "Deleting autologin tokens, this may take some time..." do
      Token.where(:action => 'autologin').delete_all
    end
  end

  def down
  end
end
