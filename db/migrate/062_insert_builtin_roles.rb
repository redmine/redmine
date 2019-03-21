class InsertBuiltinRoles < ActiveRecord::Migration[4.2]
  def self.up
    Role.reset_column_information
    nonmember = Role.new(:name => 'Non member', :position => 0)
    nonmember.builtin = Role::BUILTIN_NON_MEMBER
    nonmember.save

    anonymous = Role.new(:name => 'Anonymous', :position => 0)
    anonymous.builtin = Role::BUILTIN_ANONYMOUS
    anonymous.save
  end

  def self.down
    Role.where('builtin <> 0').destroy_all
  end
end
