module Cannon
  module Rpc
    # Include this into a service description module to make it a singleton
    # service.  Singleton services are available under a well-known id, given
    # as template argument to this.  Both the `Service` implementation and the
    # `RemoteService` client classes will automatically pick this up.
    # When adding a service instance to a `Manager` without giving an explicit
    # *id*, it'll automatically use the singleton id for a `SingletonService`.
    module SingletonService(N)
      SINGLETON_SERVICE_ID = N

      macro included
        # Returns the singleton service id
        def self.singleton_service_id : UInt32
          N.to_u32
        end
      end

      # Returns the singleton service id
      def singleton_service_id : UInt32
        N.to_u32
      end
    end
  end
end
