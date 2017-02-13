require "../src/cannon"

class Session
  include Cannon::Auto # Magic include

  property username : String
  property email : String

  def initialize(@username, @email)
  end
end

io = IO::Memory.new # Like in the example above
original = Session.new("alice", "alice@example.com")
Cannon.encode io, original
io.rewind
decoded = Cannon.decode io, Session

pp original, decoded
