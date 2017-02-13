module Cannon
  module Rpc
    # Creates a Service, which can be passed into a `Manager` and then used by
    # others through a `Connection`.
    #
    # The `T` is the service description module.  All **public** methods of `T`
    # will be remotely callable.  Please see `samples/rpc` for a usage example.
    #
    # Remotely callable methods in `T`, whose last argument, or only argument,
    # is a `Connection`, will have the calling `Connection` injected.  The
    # connection argument "disappears" from the client-side.
    #
    # A Service can only be registered to a single `Manager`.
    module Service(T)
      include GenericService

      # The following code is a bit insane.

      macro included
        include T

        RPC_METHODS = {
          0u32 => "release[]",
          {% for meth in T.methods.select{|m| m.visibility == :public} %}
            ::Cannon::Rpc::Macro.hash({{ meth.name.stringify + meth.args.stringify }}) => {{ meth.name.stringify + meth.args.stringify }},
          {% end %}
        }

        def rpc_invoke(function_hash : UInt32, io, connection : ::Cannon::Rpc::Connection) : ResponseWriter
          case function_hash
            {% for meth, idx in T.methods.select{|m| m.visibility == :public} %}
            when ::Cannon::Rpc::Macro.hash({{ meth.name.stringify + meth.args.stringify }})
              {% pass_conn = (meth.args.last && meth.args.last.restriction.is_a?(Path) && meth.args.last.restriction.resolve == Cannon::Rpc::Connection) %}

              {% if meth.args.size > (pass_conn ? 1 : 0) %}
                %args{idx} = ::Cannon.decode(io, Tuple({{
                  meth.args[0..(pass_conn ? -2 : -1)].map(&.restriction).splat
                  }}))
              {% end %}

              %result{idx} = {{ meth.name.id }}({% if meth.args.size > 0 %}
                {% if meth.args.size > (pass_conn ? 1 : 0) %}*%args{idx},{% end %}
                {% if pass_conn %}connection{% end %}
              {% end %}
              )

              {% if meth.return_type && ![ "Nil", "Void" ].includes?(meth.return_type.stringify) %}
                ->(io : IO){ ::Cannon.encode(io, %result{idx}.as({{ meth.return_type }})) }
              {% else %}
                NOOP_WRITER
              {% end %}
            {% end %}
          else
            raise ArgumentError.new("Unknown function #{function_hash}")
          end
        end

        def rpc_invoke_async(function_hash : UInt32, io, connection : ::Cannon::Rpc::Connection) : Tuple(Channel(ResponseWriter), Channel(Exception))
          ch = Channel(ResponseWriter).new
          err_ch = Channel(Exception).new

          case function_hash
            {% for meth, idx in T.methods.select{|m| m.visibility == :public} %}
            when ::Cannon::Rpc::Macro.hash({{ meth.name.stringify + meth.args.stringify }})
              {% pass_conn = (meth.args.last && meth.args.last.restriction.is_a?(Path) && meth.args.last.restriction.resolve == Cannon::Rpc::Connection) %}

              {% if meth.args.size > (pass_conn ? 1 : 0) %}
                %args{idx} = ::Cannon.decode(io, Tuple({{
                  meth.args[0..(pass_conn ? -2 : -1)].map(&.restriction).splat
                  }}))
              {% end %}

              spawn do
                begin
                  %result{idx} = {{ meth.name.id }}({% if meth.args.size > 0 %}
                    {% if meth.args.size > (pass_conn ? 1 : 0) %}*%args{idx},{% end %}
                    {% if pass_conn %}connection{% end %}
                  {% end %}
                  )

                  {% if meth.return_type && ![ "Nil", "Void" ].includes?(meth.return_type.stringify) %}
                    ch.send ->(io : IO){ ::Cannon.encode(io, %result{idx}.as({{ meth.return_type }})) }
                  {% else %}
                    ch.send NOOP_WRITER
                  {% end %}
                rescue err
                  err_ch.send err
                end
              end

              return { ch, err_ch }
            {% end %}
          else
            raise ArgumentError.new("Unknown function #{function_hash}")
          end
        end
      end
    end
  end
end
