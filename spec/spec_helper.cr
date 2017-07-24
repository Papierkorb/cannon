require "spec"
require "../src/cannon"
require "../src/cannon/rpc"

# RPC helpers
require "./rpc/service_fixtures"

## Helper methods

# If you're looking at the specs to learn how to use this library, use this
# method for inspiration.  It always uses the fastest solution, and gracefully
# falls back to slower implementations without any run-time penality.
def en_decode(value, encoded_size)
  io = IO::Memory.new
  Cannon.encode io, value

  io.pos.should eq encoded_size

  io.rewind
  Cannon.decode io, typeof(value)
end

# This version uses the slow path.  Slow is relative, really: It's still blazing
# fast .. just not that fast anymore.  It's more stable though, and if you
# prefer the more OOP-y approach, there's nothing wrong with this!
def slow_en_decode(value, encoded_size)
  io = IO::Memory.new
  value.to_cannon_io io

  io.pos.should eq encoded_size

  io.rewind
  typeof(value).from_cannon_io io
end
