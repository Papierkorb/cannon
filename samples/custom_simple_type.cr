require "../src/cannon"

@[Packed] # Go with packed if you want to go fast!
struct Addition
  include Cannon::FastAuto # Faster magic include

  property a : Int32
  property b : Int32

  def initialize(@a, @b)
  end
end

io = IO::Memory.new # Like in the example above
original = Addition.new(4, 5)
Cannon.encode io, original
io.rewind
copy = Cannon.decode io, Addition

pp original, copy
