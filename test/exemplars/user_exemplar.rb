class User < Principal
  generator_for :login, :start => 'user1'
  generator_for :mail, :method => :next_email
  generator_for :firstname, :start => 'Bob'
  generator_for :lastname, :start => 'Doe'

  def self.next_email
    @last_email ||= 'user1'
    @last_email.succ!
    "#{@last_email}@example.com"
  end
end
