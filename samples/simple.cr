require "../src/cannon" # Require the shard

# Data de-/serialization.  Cannon operates on IOs
io = IO::Memory.new # Use an in-memory store for this

original = [ 5, 6, 7 ] # Some data to serialize
Cannon.encode io, original # Write `data` into `io`
io.rewind # Don't forget to rewind the stream
copy = Cannon.decode io, typeof(original) # And read it back

pp original, copy # original == copy
