# Core extension to add #to_cannon_io and .from_cannon_io

class Object
  # Only exists to make Crystal happy
  def self.to_cannon_io(io, value)
    value.to_cannon_io io
  end
end

{% for k in [ UInt8, UInt16, UInt32, UInt64, Int8, Int16, Int32, Int64, Float32, Float64 ] %}
struct {{ k }}
  # Writes the `{{ k }}` into *io*.
  def to_cannon_io(io)
    io.write_bytes self
    io
  end

  # Creates an `{{ k }}` from *io*.
  def self.from_cannon_io(io) : self
    io.read_bytes self
  end
end
{% end %}

struct Bool
  # Writes the `Bool` into *io*.  Booleans are stored as `UInt32`s.
  def to_cannon_io(io)
    (self ? 1u8 : 0u8).to_cannon_io io
    io
  end

  # Creates a `Bool` from *io*.
  def self.from_cannon_io(io) : self
    io.read_bytes(UInt8) != 0u8
  end
end

struct Nil
  # Writes nothing into *io*.
  def to_cannon_io(io)
    io
  end

  # Reads nothing from *io*, just returns `nil`.
  def self.from_cannon_io(io)
    nil
  end
end

struct Slice(T)
  # Writes the `Slice` into *io*.
  def to_cannon_io(io)
    io.write_bytes size

    if ::Cannon.simple?(T)
      io.write to_unsafe.as(UInt8*).to_slice(bytesize)
    else
      each{|v| ::Cannon.encode(io, v)}
    end

    io
  end

  # Creates a `Slice` from *io*.
  def self.from_cannon_io(io)
    size = io.read_bytes(Int32)

    if ::Cannon.simple?(T)
      data = new size
      io.read_fully data.to_unsafe.as(UInt8*).to_slice(data.bytesize)
    else
      raise "Not implemented"
      # data = new(size){ ::Cannon.decode(io, T) }
    end

    data
  end
end

class String
  # Writes the `String` into *io*.
  def to_cannon_io(io)
    io.write_bytes bytesize
    io.write to_slice
  end

  # Creates a `String` from *io*.
  def self.from_cannon_io(io)
    bytesize = io.read_bytes(Int32)

    new bytesize do |buffer|
      io.read_fully buffer.to_slice(bytesize)
      { bytesize , 0 }
    end
  end
end

class Array(T)
  # Writes the `Array` into *io*.
  def to_cannon_io(io)
    if ::Cannon.simple?(T)
      to_unsafe.to_slice(size).to_cannon_io io
    else
      io.write_bytes size
      each{|v| ::Cannon.encode(io, v)}
    end

    io
  end

  # Creates a `Array` from *io*.
  def self.from_cannon_io(io)
    count = io.read_bytes(Int32)
    ary = new(initial_capacity: count)

    if ::Cannon.simple?(T)
      io.read_fully ary.to_unsafe.as(UInt8*).to_slice(count * sizeof(T))
      ary.size = count
    else
      count.times{ ary << ::Cannon.decode(io, T).as(T) }
    end

    ary
  end
end

class Hash(K, V)
  # Writes the `Hash` into *io*.
  def to_cannon_io(io)
    io.write_bytes size
    each do |k, v|
      ::Cannon.encode(io, k)
      ::Cannon.encode(io, v)
    end

    io
  end

  # Creates a `Hash` from *io*.
  def self.from_cannon_io(io)
    count = io.read_bytes Int32
    hsh = new

    count.times do
      key = ::Cannon.decode(io, K).as(K)
      value = ::Cannon.decode(io, V).as(V)
      hsh[key] = value
    end

    hsh
  end
end

struct Union(T)
  # Writes a value to *io*.
  def self.to_cannon_io(io, value)
    {% begin %}
      type_id = case value
      {% for type, idx in T %}
        when {{ type }} then {{ idx }}u8
      {% end %}
      else
        raise "Unknown type #{value.class}"
      end

      io.write_bytes type_id
      value.to_cannon_io(io)
      io
    {% end %}
  end

  # Creates a value from *io*.
  def self.from_cannon_io(io)
    {% begin %}
      case type_id = io.read_byte
    	{% for type, idx in T %}
        when {{ idx }}u8
          ::Cannon.decode io, {{ type }}
    	{% end %}
      else
        raise "Unknown type_id #{type_id} (Structure mismatch?)"
      end
    {% end %}
	end
end

struct Tuple(*T)
  def to_cannon_io(io)
    if ::Cannon.simple?(*{% begin %}{ {{ T.splat }} }{% end %})
      me = self
      io.write pointerof(me).as(UInt8*).to_slice(sizeof(typeof(me)))
    else
      {% begin %}
        {% for type, index in T %}
          ::Cannon.encode(io, self[{{ index }}].as({{ type }}))
        {% end %}
      {% end %}
    end

    io
  end

  def self.from_cannon_io(io)
    if ::Cannon.simple?(*{% begin %}{ {{ T.splat }} }{% end %})
      ::Cannon.fast_decode(io, T)
    else
      {% begin %}
        {
          {% for type in T %}
            ::Cannon.decode(io, {{ type }}),
          {% end %}
        }
      {% end %}
    end
  end
end

struct Time
  include Cannon::FastAuto

  def self.from_cannon_io(io)
    utc(seconds: Cannon.decode(io, Int64), nanoseconds: 0)
  end
end

struct Range(B, E)
  def to_cannon_io(io)
    @begin.to_cannon_io io
    @end.to_cannon_io io
    @exclusive.to_cannon_io io

    io
  end

  def self.from_cannon_io(io)
    new(
      ::Cannon.decode(io, B),
      ::Cannon.decode(io, E),
      ::Cannon.decode(io, Bool)
    )
  end
end

struct StaticArray(T, N)
  def to_cannon_io(io)
    if ::Cannon.simple?({{ T }})
      me = self
      io.write pointerof(me).as(UInt8*).to_slice(N * sizeof(T))
    else
      N.times do |index|
        ::Cannon.encode(io, self[index])
      end
    end
    io
  end

  def self.from_cannon_io(io)
    ary = uninitialized self
    if ::Cannon.simple?({{ T }})
      io.read_fully ary.to_unsafe.as(UInt8*).to_slice(N * sizeof(T))
    else
      N.times do |index|
        ary[index] = ::Cannon.decode(io, T)
      end
    end
    ary
  end
end
