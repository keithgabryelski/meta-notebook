require 'socket'
require 'json'

class Server
  class InvalidCommand < StandardError
  end

  attr_reader :server, :sessions, :server_hostname, :server_port
  attr_accessor :items

  def initialize(server_hostname, server_port)
    @server_hostname = server_hostname
    @server_port = server_port
    @server = TCPServer.new(server_hostname, server_port)
    @sessions = []
    @items = []
  end

  def command_reader(rfd)
    return JSON.parse(rfd.readline.chomp)
  end

  def send_response(response, rfd)
    packet = JSON.generate(response)
    rfd.write(packet + "\n")
  end

  def command_dispatcher(request, rfd)
    dispatcher_command = "_COMMAND_#{request['command']}".to_sym
    if self.respond_to?(dispatcher_command)
      response = self.send(dispatcher_command, request)
    else
      _unknown_command(request, rfd)
    end
    send_response(response, rfd)
  end

  def _unknown_command(request, rfd)
    raise InvalidCommand.new(request['command'])
  end

  def serve
    while true
      reads = [self.server] + @sessions
      rfds, wfds, efds = IO.select(reads)
      if efds.length > 0
        puts "error: #{efds.inspect}"
        @sessions -= efds
      end
      rfds.each do |rfd|
        puts "rfd: #{rfd.inspect}"
        if rfd == server
          nfd = server.accept
          @sessions << nfd
          puts "new client: #{nfd.inspect}"
        else
          close_rfd = false
          begin
            request = command_reader(rfd)
            command_dispatcher(request, rfd)
          rescue InvalidCommand => e
            puts "unknown request from client: '#{e.message}': #{rfd.inspect}"
            close_rfd = true
          rescue EOFError
            puts "client closed connection: #{rfd.inspect}"
            close_rfd = true
          rescue Exception => e
            puts "server error: #{e.message}"
            puts e.backtrace.join("\n")
            close_rfd = true
          end
          if close_rfd
            puts "closing connection to client: #{rfd.inspect}"
            @sessions -= [rfd]
            rfd.close
          end
        end
      end
    end
  end
end
