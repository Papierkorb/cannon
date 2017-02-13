module Cannon
  # Include this into your data structure (`class` or `struct`) to automatically
  # generate the `#to_cannon_io(io)` and `.from_cannon_io(io)` methods.
  #
  # Please see `AutoToIo` and `AutoFromIo` for details on each.
  # You'll need a constructor accepting a value for all instance variables.
  module Auto
    macro included
      include ::Cannon::AutoToIo
      extend ::Cannon::AutoFromIo
    end
  end

  # Much like `Auto`, but include this one instead if your structure only
  # consists of simple data types.  Do not otherwise, or your program will
  # break.
  #
  # **Note**: Only use this on `struct`s, not `class`es!  Apart from that, it
  # doesn't matter if the structure is packed or not, both are fine.
  module FastAuto
    macro included
      include ::Cannon::FastAutoToIo
      extend ::Cannon::FastAutoFromIo

      # Magic method to mark this structure as being fast en-/decodable.
      def self.use_fast_cannon?
        true
      end
    end
  end

  # Adds `#to_cannon_io(io)` to the including type.  It does so by iterating
  # over all instance variables, writing each in sequence out to *io*.
  module AutoToIo
    def to_cannon_io(io)
      {% for var in @type.instance_vars %}
        ::Cannon.encode io, @{{ var.name }}
      {% end %}

      io
    end
  end

  # Fast variant of `AutoToIo`.
  module FastAutoToIo
    def to_cannon_io(io)
      ::Cannon.encode io, self
      io
    end
  end

  # Adds `.to_cannon_io(io)` to the *extended* type.  It does so by iterating
  # over all instance variables, reading each in sequence, and calling the
  # constructor which accepts a value for all.  This constructor is not created
  # automatically.
  #
  # While the constructor needs to accept a value for all instance variables,
  # the order they appear in the prototypes argument list doesn't matter.
  module AutoFromIo
    def from_cannon_io(io)
      {% begin %}
        {{ @type }}.new(
          {% for var in @type.instance_vars %}
            {% if var.type.union? %}
              {{ var.name }}: ::Cannon.decode(io, Union({{ var.type }})).as({{ var.type }}),
            {% else %}
              {{ var.name }}: ::Cannon.decode(io, {{ var.type }}).as({{ var.type }}),
            {% end %}
          {% end %}
        )
      {% end %}
    end
  end

  # Fast variant of `AutoFromIo`.
  module FastAutoFromIo
    def from_cannon_io(io)
      {% begin %}
        ::Cannon.decode io, {{ @type }}
      {% end %}
    end
  end
end
