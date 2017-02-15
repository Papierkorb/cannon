# The Cannon [![Build Status](https://travis-ci.org/Papierkorb/cannon.svg?branch=master)](https://travis-ci.org/Papierkorb/cannon)

Really fast data de-/serialisation and remote procedure calling, for when your
process has other things to do than data serialisation.

## Benchmark

The main point about **Cannon** is speed.  This is achieved by cutting some
corners.

```crystal
io = IO::Memory.new
data = [ 5, 6, 7 ]

Benchmark.ips do |x|
  x.report("encode") do
    Cannon.encode(io, data)
    io.rewind
  end

  x.report("decode") do
    Cannon.decode(io, typeof(data))
    io.rewind
  end
end
```

On my i5 6600K (Skylake) I get numbers like these:

```
encode  96.84M ( 10.33ns) (± 4.19%)       fastest
decode  27.07M ( 36.95ns) (± 3.79%)  3.58× slower
```

## Usage

(**Tip**: You can find all of these in the [samples/](https://github.com/Papierkorb/cannon/tree/master/samples) directory)

Many common data types have support built-in:

```crystal
require "cannon" # Require the shard

# Data de-/serialization.  Cannon operates on IOs
io = IO::Memory.new # Use an in-memory store for this

original = [ 5, 6, 7 ] # Some data to serialize
Cannon.encode io, original # Write `data` into `io`
io.rewind # Don't forget to rewind the stream
copy = Cannon.decode io, typeof(data) # And read it back

pp original, copy # original == copy
```

Your own data structures can also be serialized.  Either by implementing
`#to_cannon_io(io)` and `.from_cannon_io(io)` yourself, or simply use
`Cannon::Auto`.  

```crystal
require "cannon"

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
```

Even better, if your data structure is a `struct`, `@[Packed]` and only uses
simple types, use `Cannon::FastAuto`.

```crystal
require "cannon"

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
```

### Cutting corners

You'd be surprised how much **Cannon** actually supports.  Here are some tricks
done to speed things up:

* Primitives, like `Int32`, are written directly.
* `Array`s containing simple types are basically `Slice`s.
* `Slice` is easy to blast out.
* `Slice`s not containing primitive types are not supported at the moment.
* Custom `struct`s can be marked as being "simple", meaning it can be serialized
  by type-casting it to a `Slice`.
* `Tuple`s are treated automatically as `Slice`, if they only contain "simple"
  data types.
* `Nil` is represented as nothing.
* The RPC mechanism transparently uses `UInt32` identifiers instead of method names.

However, there are things to keep in mind:

* The data format is binary and uses the host endianness
* The data is effectively unstructured, if you're using the wrong format things
  will blow up :)

### Simple data structures

Simple data structures can be read and written directly.  Their constructor,
if any, will most likely not be invoked at all, they just exist.

Requirements are as follows:
* Must be a `struct` - Not a `class`!
* Only contains other "simple" data, like *primitives*
* Does not contain any variable-length data like `Slice`s or `Array`s

Do not falter: If your data-structure does not fit these, you can still use it
just fine!  It just means it will be fast, but not blazing fast :)

## RPC

**Cannon** also comes with a RPC module.  It does the heavy lifting for you, so
that you can focus on actually writing code.  And it's fast too!

Want to see some real code? Look into [samples/rpc/](https://github.com/Papierkorb/cannon/tree/master/samples/rpc)!

### Services

The RPC module works on a service methodology.  A server provides one, or more
services for a client to consume.  In **Cannon**, both ends can provide services
for the other to consume.

For this to work, you need three components per Service:
1. The description module, which describes the interface through `abstract`
   methods.
2. The service class, which includes `Cannon::Rpc::Service`.  This object lives
   on the server.  There can be one or more instances of each service.  Each
   instance has its own unique *identifier*, or *id*, which is a `UInt32`.  A
   service can be owned by a client, more on that below.
3. The client class, which includes `Cannon::Rpc::RemoteService`.  This object
   lives on the client.  It's bound to a `Cannon::Rpc::Connection` and the
   remote services *id*.

In real usage, you'll probably have two kinds of services: First, those used by
every client, and second, those used exclusively by one (or few) client(s).

#### Singleton services

Singleton services have no owner (Its owner is `nil`), and are registered to
well-known a identifiers.  Usually, only one instance of this service exists on
the server.

You can make your life easy by including `Cannon::Rpc::SingletonService` into
the description module of the service.  This module is instantiated with an
identifier.  When you now derive your service and client classes from it,
they'll automatically bind to the singletons service identifier.

#### Instance services

The second kind of services are instance services.  These are used exclusively
by one client, or by few clients.  If there's only one client, you can give the
client ownership over that service instance.

When a client owns a service, it may release it (remove it) later on.  This can
be done through the `#release_now!` method of a client class.  Or you just
forget about the client, wait until it's garbage-collected, and it'll
automatically be released remotely for you.  The same happens when a connection
is closed automatically, too.

#### The client

The client is more or less auto-generated from the description module using
`Cannon::Rpc::RemoteService`.  An actually complete example is this:

```crystal
class MyServiceClient
  include Cannon::Rpc::RemoteService(MyServiceDescription)
end
```

That's it!  The class will get a `#initialize`r which you pass the `Connection`
first and the service id (optional if it's a singleton service).  The
implemented abstract methods from the description module will point at the
remote service, and function like normal methods to you.

If you don't care about the methods results anyway, use the
`_without_response` version, which is also generated for each method.

```crystal
  my_client.greet("Alice") # Wait for response
  my_client.greet_without_response("Alice") # Don't wait
```

#### Getting the calling connection

One last thing: If you need to know which `Connection` exactly is making the
call in your service class, just add an argument of type `Connection` to the
end of the argument list.  For the client, this argument will "disappear". The
service instance will have it "injected".

### Gotchas and Troubleshooting

#### Type your method arguments and result

It's really important to type your methods.  It's acceptable to not type the
result, in which case it's treated as `Nil`, and thus will **silently drop**
anything returned from the method.

```crystal
# Won't work
abstract def add(a, b)
abstract def greet(user : String, email)
abstract def return_something_important

# Will work fine
abstract def add(a : Int32 | Float32, b : Int32) : Float64
abstract def greet(user : String, email : String?) : String
abstract def return_something_important : Hash(String, Int32)
```

#### You can't just pass a Service instance around

Right now, you can't pass a `Service` or `RemoteService` instance around.
Pass around its *service_id* instead, and rebuild the client on the other
end.

```crystal
# Won't compile
def create_chat_room(name : String) : ChatRoomService
  ChatRoomService.new(name)
end

# Will work fine
def create_chat_room_service(name : String) : UInt32
  manager.add ChatRoomService.new(name)
end
```

Then, add a wrapper method to your client doing the conversion for you:

```crystal
class ChatClient
  # ...

  def create_chat_room(name : String) : ChatRoomClient
    ChatRoomClient.new connection, create_chat_room_service(name)
  end
end
```

## When to use **The Cannon**

1. **Speed** is your primary concern
2. You don't care about **inter-operability**
3. You're fine with **sacrificing structure**

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  cannon:
    github: Papierkorb/cannon
```

## Contributing

1. Fork it ( https://github.com/Papierkorb/cannon/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## License

This library is licensed under the Mozilla Public License 2.0 ("MPL-2").

For a copy of the full license text see the included `LICENSE` file.

For a legally non-binding explanation visit:
[tl;drLegal](https://tldrlegal.com/license/mozilla-public-license-2.0-%28mpl-2%29)

## Contributors

- [Papierkorb](https://github.com/Papierkorb) Stefan Merettig - creator, maintainer

## Still looking down here?

Have nice day!
