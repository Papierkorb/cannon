module Cannon
  module Rpc
    # A (network) connection to invoke remote methods.
    # Use a `RemoteService` instead of using the methods in this class directly.
    abstract class Connection
      # Is the connection running?
      getter? running : Bool = true

      # The `Manager` used to offer services to the remote side.
      getter manager : Manager

      @on_local_error : Exception -> Nil
      @on_remote_error : RemoteError -> Nil

      def initialize(@manager : Manager)
        @on_local_error = ->(_e : Exception){ }
        @on_remote_error = ->(_e : RemoteError){ }
      end

      # Sets a handler called when a locally called method threw an error.
      def on_local_error(&block : Exception -> _)
        @on_local_error = block
      end

      # Sets a handler called when a remotely called method threw an error.
      def on_remote_error(&block : RemoteError -> _)
        @on_remote_error = block
      end

      # Closes the connection gracefully (if possible).
      def close
        if @running
          @manager.release_all_services self
        end

        @running = false
      end

      # Calls the function (through *function_hash*) on *service_id* using
      # *arguments*.  Yields an `IO` when the response was received and must
      # be read from it using `Cannon.decode`.  If a remote error was
      # encountered, the block is *not* called, and is raised locally.
      #
      # This method blocks the current Fiber.
      abstract def call_remotely(service_id : UInt32, function_hash : UInt32, arguments : Tuple?, &block : IO -> _)

      # Like `call_remotely`, but doesn't request a response.  A response is
      # never requested and thus is never received.
      #
      # **Note**: This will also silence any error propagation from the remote
      # side back to the local side.
      #
      # This method **does not** block the current Fiber.
      abstract def call_remotely(service_id : UInt32, function_hash : UInt32, arguments : Tuple?)

      # Releases the local *service_id*, requested by this connection.
      def release_service(service_id : UInt32)
        @manager.release service_id, self
      end

      # Releases the remote *service_id*
      abstract def release_remote_service(service_id : UInt32)

      # Starts a read-loop, blocking the current Fiber.
      abstract def run
    end

    class NullConnection < Connection
      INSTANCE = new(Manager.new)

      def call_remotely(service_id : UInt32, function_hash : UInt32, arguments : Tuple?, &block : IO -> _); end
      def call_remotely(service_id : UInt32, function_hash : UInt32, arguments : Tuple?); end
      def release_remote_service(service_id : UInt32); end
      def run; end
    end
  end
end
