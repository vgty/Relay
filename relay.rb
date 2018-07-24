require 'socket'
require 'http_parser'
require 'stringio'
require 'thread'

class Relay
  def initialize(port, app)
    @server_socket = TCPServer.new(port)
    @app = app
  end
  
  def start
    loop do
      client_socket = @server_socket.accept
      Thread.new do
        connection = Connection.new(client_socket, @app)
        connection.process
      end
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
    
    REASONS = {
      200 => "OK",
      404 => "Not Found"
    }
    
    def send_response(env)
      
      status, headers, body = @app.call(env)
      reason = REASONS[status]
      
      @client_socket.write "HTTP/1.1 #{status} #{reason} \r\n"
      headers.each_pair do |name, value|
        @client_socket.write "#{name}: #{value}\r\n"
      end
      @client_socket.write "\r\n"
      body.each do |part|
        @client_socket.write part
      end
      
      close
    end
    
    
     
    def close
      @client_socket.close
    end
  end
  
  class Builder
    attr_reader :app

    def run(app)
      @app = app
    end

    def self.parse_file(file)
      content = File.read(file)
      builder = self.new
      builder.instance_eval{content}
      builder.app
    end
  end
end

app = Relay::Builder.parse_file("config.ru")
server = Relay.new(3000, app) 
puts "Server will start on port 3000"
server.start