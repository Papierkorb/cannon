require "../../src/cannon"
require "../../src/cannon/rpc" # Explicitly require this one

require "./description"

class GreetClient
  include Cannon::Rpc::RemoteService(GreetDescription)
end

socket = TCPSocket.new "localhost", 4711
socket.tcp_nodelay = true
socket.sync = true

service_manager = Cannon::Rpc::Manager.new
connection = Cannon::Rpc::TcpConnection.new service_manager, socket
greeter = GreetClient.new connection

spawn{ connection.run }
pp greeter.greet("Alice")
pp greeter.greet([ "Alice", "Bob", "Charlie" ])

start = Time.now
pong = greeter.ping Time.now
finish = Time.now

puts "      Ping time: #{pong - start}"
puts "Round-trip time: #{finish - start}"
