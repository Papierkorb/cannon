module Cannon
  module Rpc
    # A TCP-based network connection.  See `Connection` for usage details.
    #
    # This connection allows for concurrent requests, up to 256 at once.
    class TcpConnection < Connection
      # Creates a connection using the given *manager* and communicating through
      # the given *socket*.
      def initialize(manager : Manager, @socket : TCPSocket)
        super manager
        @handles = Hash(UInt8, Channel(Protocol::Header)).new
      end

      def close
        @socket.close
        super
      end

      def call_remotely(service_id : UInt32, function_hash : UInt32, arguments : Tuple?, &block : IO -> _)
        handle = find_handle

        ch = Channel(Protocol::Header).new
        @handles[handle] = ch

        send_call service_id, function_hash, arguments, handle, true

        wait_for_response(handle, ch) do
          yield @socket
        end
      end

      def call_remotely(service_id : UInt32, function_hash : UInt32, arguments : Tuple?)
        send_call service_id, function_hash, arguments, 0u8, false
        nil
      end

      def release_remote_service(service_id : UInt32)
        send_call(0xFFFFFFFFu32, 0xFFFFFFFFu32, service_id, 0u8, false)
        nil
      end

      private def send_call(service_id, function_hash, arguments, handle, wait)
        header = Protocol::Header.new(
          flags: call_flags(wait),
          handle: handle,
          service_id: service_id,
          method: function_hash,
        )

        send_buffer do |io|
          Cannon.encode(io, header)
          Cannon.encode(io, arguments)
        end
      end

      private def wait_for_response(handle, ch)
        header = ch.receive
        @handles.delete handle

        if header.flags.remote_error?
          handle_remote_error
        else
          yield
        end
      end

      private def handle_remote_error
        err = Cannon.decode(@socket, Protocol::ErrorResponse)

        error = RemoteError.new(err.type, err.message)
        @on_remote_error.call(error)
        raise error
      end

      private def call_flags(with_response)
        if with_response
          Protocol::Flags::None
        else
          Protocol::Flags::VoidCall
        end
      end

      private def find_handle
        id = (0u8..255u8).find{|i| !@handles.includes?(i)}

        if id.nil?
          raise "Unable to find unused handle!"
        end

        id
      end

      # Starts a read-loop, blocking the current Fiber.
      def run
        while @running
          handle_next
        end
      ensure
        close
      end

      private def handle_next
        header = Cannon.decode(@socket, Protocol::Header)

        if header.flags.result_value?
          handle_response header
        elsif header.service_id == 0xFFFFFFFFu32 && header.method == 0xFFFFFFFFu32
          handle_release
        else
          handle_call header
        end
      end

      private def handle_release
        service_id = Cannon.decode @socket, UInt32
        @manager.release service_id, owner: self
      end

      private def handle_response(header)
        if waiter = @handles[header.handle]?
          waiter.send header
        else
          @on_local_error.call UnknownResponse.new("Unknown response with handle #{header.handle}")
        end
      end

      private def handle_call(header)
        target_service = @manager[header.service_id]
        ch, err_ch = target_service.rpc_invoke_async(header.method, @socket, self)
        @socket.flush

        spawn do
          handle_result ch, err_ch, header
        end
      end

      private def handle_result(channel, error_channel, header)
        case
        when writer = channel.receive
          send_response(header, writer) unless header.flags.void_call?
        when error = error_channel.receive
          @on_local_error.call error
          send_error(header, error) unless header.flags.void_call?
        end
      end

      private def send_response(header, response)
        header.flags = Protocol::Flags.flags(ResultValue)

        send_buffer do |io|
          Cannon.encode io, header
          response.call io
        end
      end

      private def send_error(header, error)
        header.flags = Protocol::Flags.flags(ResultValue, RemoteError)
        response = Protocol::ErrorResponse.new(
          type: error.class.name,
          message: error.message.to_s,
        )

        send_buffer do |io|
          Cannon.encode io, header
          Cannon.encode io, response
        end
      end

      private def send_buffer
        io = IO::Memory.new
        yield io
        @socket.write io.to_slice
        @socket.flush
      end
    end
  end
end
