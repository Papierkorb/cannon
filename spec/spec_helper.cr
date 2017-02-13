require "spec"
require "../src/cannon"
require "../src/cannon/rpc"

# RPC helpers
require "./rpc/service_fixtures"

## Helper methods

# If you're looking at the specs to learn how to use this library, use this
# method for inspiration.  It uses always the fastest solution, and gracefully
# falls back to slower implementations without any run-time penality.
def en_decode(value, encoded_size)
  io = IO::Memory.new
  Cannon.encode io, value

  io.pos.should eq encoded_size

  io.rewind
  Cannon.decode io, typeof(value)
end

def slow_en_decode(value, encoded_size)
  io = IO::Memory.new
  value.to_cannon_io io

  io.pos.should eq encoded_size

  io.rewind
  typeof(value).from_cannon_io io
end
