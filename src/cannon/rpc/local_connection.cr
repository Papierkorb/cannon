module Cannon
  module Rpc
    # A process-local connection, useful for debugging and testing.
    # The whole stack is ran through, that is, services, data serialisation, and
    # everything, is used like normal.
    class LocalConnection < Connection
      def call_remotely(service_id : UInt32, function_hash : UInt32, arguments : Tuple?, &block : IO -> _)
        writer = do_call(service_id, function_hash, arguments, true)
        yield result_to_io(writer.not_nil!)
      end

      # No-result version, runs concurrently in a background fiber.
      def call_remotely(service_id : UInt32, function_hash : UInt32, arguments : Tuple?)
        spawn{ do_call(service_id, function_hash, arguments, false) }
      end

      private def result_to_io(writer)
        io = IO::Memory.new
        writer.call io
        io.rewind
        io
      end

      private def do_call(service_id, func, arguments, propagate)
        mimic_remote_error(propagate) do
          in_io = serialize(arguments)
          @manager[service_id].rpc_invoke func, in_io, self
        end
      end

      private def mimic_remote_error(propagate)
        yield
      rescue error
        @on_local_error.call error

        if propagate
          remote_err = RemoteError.new(error.class.name, error.message)
          @on_remote_error.call remote_err
          raise remote_err
        end
      end

      private def serialize(value)
        io = IO::Memory.new
        ::Cannon.encode io, value
        io.rewind
        io
      end

      def run
        # Does nothing.
      end

      def release_remote_service(service_id : UInt32)
        release_service service_id
      end
    end
  end
end
