require 'webrick'

server = WEBrick::HTTPServer.new(:Port => 3000)

server.mount_proc '/mail_handler' do |req, res|
  puts "Received request!"
  puts "Headers: #{req.header}"
  puts "Body: #{req.body}"
  
  if req.query['key'] == 'secret'
    res.status = 201
    res.body = "Created"
  else
    res.status = 403
    res.body = "Forbidden"
  end
end

trap 'INT' do server.shutdown end

puts "Mock Redmine Server started on http://localhost:3000"
server.start
