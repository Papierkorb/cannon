module Cannon
  module Rpc
    # Work-around helper to store untyped `Service` instances.
    # You're probably looking for `Service` or `RemoteService`.
    module GenericService
      alias ResponseWriter = IO -> IO
      NOOP_WRITER = ->(io : IO){ io }

      # The `Manager` this service is registered to
      property! manager : Manager?

      # The `Connection` owning this service
      property owner : Connection?

      # The service id
      property! service_id : UInt32?

      abstract def rpc_invoke(function_hash : UInt32, io, connection : Connection) : ResponseWriter
      abstract def rpc_invoke_async(function_hash : UInt32, io, connection : Connection) : Tuple(Channel(ResponseWriter), Channel(Exception))
    end
  end
end
