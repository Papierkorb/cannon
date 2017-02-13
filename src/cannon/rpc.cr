require "socket"
require "./rpc/*"

module Cannon
  # Base module for the RPC functionality
  module Rpc
    # Generic error class used by `Rpc` classes
    class Error < Exception
    end

    # Used when a response for an unknown handle was encountered
    class UnknownResponse < Error
    end

    # Remote error class, raised when a remote call encountered an error
    class RemoteError < Error
      # The remote exception type, like "ArgumentError"
      getter type : String

      # The remote error message
      getter remote_message : String

      def initialize(@type, remote_message)
        @remote_message = remote_message || ""
        super("#{@type}: #{@remote_message}")
      end
    end
  end
end
