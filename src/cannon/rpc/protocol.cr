module Cannon
  module Rpc
    # Protocol structures.  May be used by `Connection` implementations.
    module Protocol

      # Flags for the `Header`
      @[Flags]
      enum Flags : UInt8
        # This is a result value, not a function call
        ResultValue = 0x01

        # The remote end encountered an error while processing the call
        RemoteError = 0x02

        # This is a call, but the result shall not be sent
        VoidCall = 0x04
      end

      # Protocol header, can be fast-serialized
      @[Packed]
      struct Header
        include Cannon::FastAuto

        property flags : Flags
        property handle : UInt8
        property service_id : UInt32
        property method : UInt32

        def initialize(@flags, @service_id, @method, @handle = 0u8)
        end
      end

      # Response packet for remote errors
      @[Packed]
      struct ErrorResponse
        include Cannon::Auto

        # The remote exception type, like "ArgumentError"
        property type : String

        # The remote error message
        property message : String

        def initialize(@type : String, @message : String)
        end
      end
    end
  end
end
