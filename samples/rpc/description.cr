module GreetDescription
  include Cannon::Rpc::SingletonService(1)

  abstract def greet(name : String) : String
  abstract def greet(names : Array(String)) : String
  abstract def ping(client_time : Time) : Time
end
