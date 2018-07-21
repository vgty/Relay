require 'socket'
require 'http_parser'
require 'stringio'

class Relay
  def initialize(port, app)
    @server_socket = TCPServer.new(port)
    @app = app
  end
  
  def start
    loop do
      client_socket = @server_socket.accept
      connection = Connection.new(client_socket, @app)
      connection.process
    end 
  end
  
  class Connection
    
    def initialize(client_socket, app)
      @client_socket = client_socket
      @parser = Http::Parser.new(self)
      @app = app
    end
    
    def process
      until @client_socket.closed? || @client_socket.eof?
        data = @client_socket.readpartial(1024)
        @parser << data
      end
    end
    
    def on_message_complete
      puts "#{@parser.http_method} #{@parser.request_url}"
      puts "   " + @parser.headers.inspect
      
      env = {}
      @parser.headers.each_pair do |name, value|
        name = "HTTP_" + name.upcase.tr("-","_")
        env[name]= value
      end
      
      env["PATH_INFO"] = @parser.request_url
      env["REQUEST_METHOD"] = @parser.http_method
      env["rack.input"] = StringIO.new
      
      send_response(env)
    end
    
    def send_response(env)
      status, headers, body = @app.call(env)

      @client_socket.write "HTTP/1.1 200 OK \r\n"
      @client_socket.write "\r\n"
      @client_socket.write "Hello World\n"
      close
    end
    
    
     
    def close
      @client_socket.close
    end
  end
end

class App
  def call(env)
    message = "Hello from the #{Process.pid}.\n"
    [
      200,
      { 'Content-Type' => 'text/plain', 'Content-Length' => message.size.to_s },
      [message]
    ]
  end
end


app = App.new
server = Relay.new(3000, app) 
puts "Server will start on port 3000"
server.start