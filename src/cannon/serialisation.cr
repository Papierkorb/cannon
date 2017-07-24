module Cannon
  # Serializes *value* into *io*.  Returns the *io*.
  # Always use this method (And `Cannon.decode`) over the instance methods.
  # The `Cannon` methods will always use the fastest-path available, gradually
  # falling back to slower implementations.  This mechanism does not incur any
  # run-time penality.
  #
  # To add support for your own data structures, implement:
  # * `#to_cannon_io(io)` to write *self* into *io*
  # * `.from_cannon_io(io)` to construct an instance out of *io*
  #
  # Make sure to use `Cannon.encode` in your `#to_cannon_io` method, and
  # `Cannon.decode` in your `.from_cannon_io` method, for optimal speed.
  #
  # You can automate this by including `Cannon::Auto` into your structure.
  def self.encode(io, value)
    if typeof(value) != value.class # Union type?
      Union(typeof(value)).to_cannon_io(io, value)
    elsif value.nil?
      # Do nothing.
    elsif simple?(typeof(value)) # Simple type?
      fast_encode(io, value)
    else # Too complex to just memcpy() it
      value.to_cannon_io io
    end

    io
  end

  # Deserializes *type* from *io*, returning the result.
  macro decode(io, type)
    if {{ type }} == Nil
      nil
    elsif ::Cannon.simple?({{ type }})
      ::Cannon.fast_decode({{ io }}, {{ type }})
    else
      Union({{ type }}).from_cannon_io({{ io }})
    end.as({{ type }})
  end

  # Helper method to check if all data types in *tuple* are "simple".  A simple
  # data type can be serialized by essentially pointer-casting it to `Bytes` and
  # then blasting it into `IO#write`.
  def self.simple?(*tuple)
    tuple.all? do |type|
      {
        UInt8, UInt16, UInt32, UInt64,
        Int8, Int16, Int32, Int64,
        Float32, Float64,
        Bool
      }.includes?(type) || \
        type.responds_to?(:use_fast_cannon?) || \
        (type == Tuple && type.responds_to?(:map) && ::Cannon.simple?(type.map(&.class)))
        # The above `responds_to?(:map)` just tells the compiler that indeed,
        # Tuples respond to `#map`.
    end
  end

  # Helper macro to write *value* into *io* as-is.
  # *value* must be a variable and can not be a literal or `self`.
  macro fast_encode(io, value)
    {{ io }}.write(pointerof({{ value }}).as(UInt8*).to_slice(sizeof(typeof({{ value }}))))
  end

  # Helper macro to read a *type* from *io* as-is.
  macro fast_decode(io, type)
    begin
      %value = uninitialized {{ type }}
      {{ io }}.read_fully pointerof(%value).as(UInt8*).to_slice(sizeof({{ type }}))
      %value
    end
  end
end
