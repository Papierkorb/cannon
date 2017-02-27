module Cannon
  module Rpc
    # Accepts connections from a `TCPServer` and calls `TcpConnection#run` for
    # each new connection, using the passed `Manager`.
    #
    # Call `#run` to start accepting connections.
    class TcpAcceptor
      getter? running : Bool = true

      # The used manager
      getter manager : Manager

      # The used tcp server
      getter server : TCPServer

      # Will accept connections from *server* and pass *manager* into the
      # created `TcpConnection`.
      #
      # The *tcp_nodelay* and *sync* arguments will be set in all accepted TCP
      # connections.
      def initialize(@manager : Manager, @server : TCPServer, @tcp_nodelay : Bool = false, @sync : Bool = false)
        @running = true
        @on_new_connection = ->(x : TcpConnection){ nil }
      end

      # Closes the server and stops accepting connections.
      def close
        @running = false
        @server.close
      end

      # Sets a handler called when a new connection was accepted.
      # If you want to reject it, just call `#close` on the passed
      # `TcpConnection`.
      def on_new_connection(&block : TcpConnection -> Nil)
        @on_new_connection = block
      end

      # Starts accepting TCP connections, blocking the current Fiber, until
      # `#close` is called.
      def run
        while @running
          accept_socket @server.accept?
        end
      end

      protected def create_connection(socket)
        socket.tcp_nodelay = @tcp_nodelay
        socket.sync = @sync
        TcpConnection.new(@manager, socket)
      end

      protected def accept_socket(socket)
        return if socket.nil? # Socket was closed
        conn = create_connection socket

        spawn do
          @on_new_connection.call conn
          conn.run
        end
      end
    end
  end
end
