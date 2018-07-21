require 'socket'

class Relay
  def initialize(port)
    @server = TCPServer.new(port)
  end
  
  def start
    loop do
      socket = @server.accept
      puts socket.class
      data = socket.readpartial(1024)
      puts data
      socket.write "HTTP/1.1 200 OK \r\n"
      socket.write "\r\n"
      socket.write "Hello World\n"
      

      socket.close
    end 
  end
end

server = Relay.new(3000) 
puts "Server will start on port 3000"
server.start