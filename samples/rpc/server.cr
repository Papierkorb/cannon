require "../../src/cannon"
require "../../src/cannon/rpc" # Explicitly require this one

require "./description"

class GreetService
  include Cannon::Rpc::Service(GreetDescription)

  def greet(name : String) : String
    puts "Greeting #{name}"
    "Hello #{name}!"
  end

  def greet(names : Array(String)) : String
    puts "Greeting #{names.size} people"
    last = names.pop

    "Hello #{names.join ", "} and #{last}"
  end

  def ping(client_time : Time) : Time
    my_time = Time.now
    puts "Client ping: #{my_time - client_time}"
    my_time
  end
end

service_manager = Cannon::Rpc::Manager.new
service_manager.add GreetService.new

tcp_server = TCPServer.new("localhost", 4711)
acceptor = Cannon::Rpc::TcpAcceptor.new service_manager, tcp_server
acceptor.run
