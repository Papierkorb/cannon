module Cannon
  module Rpc
    # Include this into a client class to access a specific remote service
    # through a `Connection`.
    #
    # The `T` is the description module.  For all **public** methods in `T` a
    # method will be generated, which forwards the call to the remote end. By
    # default, the invocation will wait for a response to return it, or to raise
    # a `RemoteError` when an error occured.  Each method also exists in a
    # `without_response` version, which if used, will not wait for the remote
    # end to finish the work.  This also means that any result (or encountered
    # error) will be silently dropped.
    #
    # ## Calling Example
    # ```crystal
    # my_service = MyServiceClient.new(my_connection, the_identifier)
    # pp my_service.greet("You") # Will wait for the response
    # pp my_service.greet_without_response("You") # Will NOT wait
    # ```
    #
    # Please see `samples/rpc` for a complete usage example.
    module RemoteService(T)
      macro included
        include T

        {% for meth in T.methods.select{|m| m.visibility == :public && m.name != "singleton_service_id"} %}
          {% pass_conn = (meth.args.last && meth.args.last.restriction.is_a?(Path) && meth.args.last.restriction.resolve == Cannon::Rpc::Connection) %}
          {% conn_arg = meth.args.last.name if pass_conn %}
          {% args = pass_conn ? meth.args[0...-1] : meth.args %}

          def {{ meth.name }}(
            {% for arg in args %}
              {{ arg.name }} : {{ arg.restriction }} {% if arg.default_value %} = {{ arg.default_value }} {% end %},
            {% end %}
            {% if pass_conn %}*, {{ conn_arg }} : Cannon::Rpc::Connection = Cannon::Rpc::NullConnection::INSTANCE{% end %}
          )
            func = ::Cannon::Rpc::Macro.hash({{ meth.name.stringify + meth.args.stringify }})

            {% result = (meth.return_type.stringify == "Void") ? Nil : (meth.return_type || Nil) %}
            @connection.call_remotely(@service_id, func,
              {% if args.size < 1 %}
                nil
              {% else %}
                {
                  {% for arg in args %}
                    {{ arg.name }}.as({{ arg.restriction }}),
                  {% end %}
                }
              {% end %}
            ) do |io|
              ::Cannon.decode io, {{ result }}
            end.as({{ result }})
          end

          {% no_resp_name = meth.name + "_without_response" %}
          {% no_resp_name = meth.name[0...-1] + "_without_response?" if meth.name.ends_with?('?') %}
          {% no_resp_name = meth.name[0...-1] + "_without_response!" if meth.name.ends_with?('!') %}
          def {{ no_resp_name }}(
            {% for arg in args %}
              {{ arg.name }} : {{ arg.restriction }} {% if arg.default_value %} = {{ arg.default_value }} {% end %},
                {% if pass_conn %}*, {{ conn_arg }} : Cannon::Rpc::Connection = Cannon::Rpc::NullConnection::INSTANCE{% end %}
            {% end %}
          )
            func = ::Cannon::Rpc::Macro.hash({{ meth.name.stringify + meth.args.stringify }})

            {% result = (meth.return_type.stringify == "Void") ? Nil : (meth.return_type || Nil) %}
            @connection.call_remotely(@service_id, func,
              {% if args.size < 1 %}
                nil
              {% else %}
                {
                  {% for arg in args %}
                    {{ arg.name }}.as({{ arg.restriction }}),
                  {% end %}
                }
              {% end %}
            )
            nil
          end
        {% end %}

        {% if T <= Cannon::Rpc::SingletonService %}
          # Instantiates a client over *connection* to the singleton service.
          def initialize(
            @connection : Cannon::Rpc::Connection,
            @service_id : UInt32 = singleton_service_id,
            @owned : Bool = false
          )
          end
        {% end %}
      end

      # The connection used to reach the remote `Service` object
      getter connection : Connection

      # The id of the remote `Service` object
      getter service_id : UInt32

      # Do we own this service?
      getter? owned : Bool

      # Instantiates a client over *connection* to the service.
      def initialize(@connection : Connection, @service_id : UInt32, @owned : Bool = false)
      end

      # Releases ("free's") the remote service if we own it.
      # Automatically called on `#finalize`, so it's done automatically when
      # this object is garbage-collected.
      def release_now!
        @connection.release_remote_service(@service_id) if @owned
        @owned = false
      end

      # Release the remote service on garbage-collection.
      def finalize
        release_now!
      end
    end
  end
end
