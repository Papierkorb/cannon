module FooDescription
  abstract def do_it : String

  abstract def overloaded(a : Int32, b : Int32) : Int32
  abstract def overloaded(a : String, b : String) : String

  abstract def union_arg(a : Int32 | String) : String
  abstract def union_result(a : String) : Int32 | String

  abstract def raise_an_error

  abstract def tell_me(conn : Cannon::Rpc::Connection) : String
  abstract def tell_me(leading : String, conn : Cannon::Rpc::Connection) : String
end

module BarDescription
  include Cannon::Rpc::SingletonService(2)

  abstract def do_it : String
  abstract def something_else : String
end

class FooService
  include Cannon::Rpc::Service(FooDescription)

  def do_it : String
    "Foo!"
  end

  def overloaded(a : Int32, b : Int32) : Int32
    a + b
  end

  def overloaded(a : String, b : String) : String
    a + b
  end

  def union_arg(a : Int32 | String) : String
    (a * 2).to_s
  end

  def union_result(a : String) : Int32 | String
    a.to_i? || "NaN"
  end

  def raise_an_error
    raise "Something went wrong!"
  end

  def tell_me(conn : Cannon::Rpc::Connection) : String
    conn.to_s
  end

  def tell_me(leading : String, conn : Cannon::Rpc::Connection) : String
    leading + conn.to_s
  end
end

class BarService
  include Cannon::Rpc::Service(BarDescription)

  def do_it : String
    "Bar!"
  end

  def something_else : String
    "Bar!"
  end
end

class FooClient
  include Cannon::Rpc::RemoteService(FooDescription)
end

class BarClient
  include Cannon::Rpc::RemoteService(BarDescription)
end

def build_manager
  manager = Cannon::Rpc::Manager.new
  manager.add FooService.new, id: 1u32
  manager.add BarService.new
  manager
end

def build_connection(manager = build_manager)
  Cannon::Rpc::LocalConnection.new(manager)
end
