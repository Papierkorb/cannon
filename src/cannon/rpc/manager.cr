module Cannon
  module Rpc
    # Manages local `Service` instances, which are then offered through
    # `Connection`s.
    class Manager
      property services : Hash(UInt32, GenericService)
      @next_id : UInt32 = 0u32

      delegate :[], :[]?, to: @services

      def initialize
        @services = Hash(UInt32, GenericService).new
      end

      # Adds a locally running *service* for *owner* to the manager.
      # If *owner* is not `nil`, the *service* is said to be owned by that
      # connection, and (only) this connection shall be allowed to release it
      # (remove it) later on again.  If you don't need or want this behaviour
      # for a service, simply pass `nil`.
      # If no *id* is given, a unused one will be chosen automatically.  If the
      # *service* is a `SingletonService`, the *id* will be set to the assigned
      # *id* in this case.
      # If a *id* is given, it will be used, and may override an already
      # existing service.
      def add(service : GenericService, owner : Connection? = nil, id : UInt32? = nil) : UInt32
        raise ArgumentError.new("service is already owned by a manager") if service.manager?

        if id.nil?
          if service.responds_to?(:singleton_service_id)
            id = service.singleton_service_id
          else
            id = next_id
          end
        end

        service.manager = self
        service.owner = owner
        service.service_id = id
        @services[id] = service

        id
      end

      private def next_id
        # Start recycling identifiers?
        if @next_id / 2 > @services.size
          @next_id = 0u32
        end

        while @services.has_key?(@next_id)
          @next_id += 1
        end

        @next_id
      end

      # Releases *service*.
      def release(service : GenericService)
        release service.service_id, service.owner
      end

      # Releases the service *service_id* of *owner*.  If the *owner* does not
      # match, an `Error` is raised.
      def release(service_id : UInt32, owner : Connection? = nil)
        service = @services[service_id]

        if service.owner == owner
          @services.delete service_id
        else
          raise Error.new("Connection #{owner} tried to release service #{service_id}, but it's owned by #{service.owner.inspect}")
        end
      end

      # Releases all services of *owner*.
      def release_all_services(owner : Connection) : Nil
        @services.delete_if do |_id, service|
          service.owner == owner
        end
      end

      def has_service?(service_id : UInt32) : Bool
        @services.has_key? service_id
      end
    end
  end
end
