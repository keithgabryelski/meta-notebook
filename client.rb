require 'socket'

class Client
  attr_reader :client, :server_hostname, :server_port

  def initialize(server_hostname, server_port)
    @server_hostname = server_hostname
    @server_port = server_port
    @client = TCPSocket.new(server_hostname, server_port)
  end

  def serve
    while true
      begin
        line = command_reader
        command_dispatcher(line)
      rescue EOFError
        puts "server closed connection: #{client.inspect}"
        client.close
        break
      end
    end
  end
end
