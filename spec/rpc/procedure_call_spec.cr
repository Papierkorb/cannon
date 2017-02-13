require "../spec_helper"

private def my_service
  conn = build_connection
  FooClient.new conn, 1u32
end

describe "procedure calling" do
  it "makes a call" do
    my_service.do_it.should eq "Foo!"
  end

  it "supports method overloading" do
    my_service.overloaded(3, 4).should eq 7
    my_service.overloaded("Wi", "ng").should eq "Wing"
  end

  it "supports union arguments" do
    my_service.union_arg(5).should eq "10"
    my_service.union_arg("5").should eq "55"
  end

  it "supports union result value" do
    my_service.union_result("7").should eq 7
    my_service.union_result("Stuff").should eq "NaN"
  end

  it "propagates remote errors back to the caller" do
    svc = my_service
    sequence = [ ] of Int32

    svc.connection.on_local_error{|_e| sequence << 1; nil}
    svc.connection.on_remote_error{|_e| sequence << 2; nil}

    expect_raises(Cannon::Rpc::RemoteError) do
      svc.raise_an_error
    end

    sequence.should eq [ 1, 2 ]
  end

  it "supports call-and-forget" do
    my_service.do_it_without_response.should eq nil
    Fiber.yield # Run the method
  end

  it "ignores errors on call-and-forget" do
    svc = my_service
    sequence = [ ] of Int32

    svc.connection.on_local_error{|_e| sequence << 1; nil}
    svc.connection.on_remote_error{|_e| sequence << 2; nil}

    svc.raise_an_error_without_response # Doesn't raise on our end
    Fiber.yield # Wait for the method to run

    sequence.should eq [ 1 ]
  end

  it "can release the remote service manually" do
    conn = build_connection
    svc_id = conn.manager.add(FooService.new, owner: conn)
    client = FooClient.new conn, svc_id, true
    conn.manager.has_service?(client.service_id).should eq true

    client.release_now!
    conn.manager.has_service?(client.service_id).should eq false
  end

  # Flaky test
  it "releases the remote service automatically" do
    conn = build_connection
    svc_id = conn.manager.add(FooService.new, owner: conn)

    # Build the owning client in a separate scope
    builder = -> do
      client = FooClient.new conn, svc_id, true
      conn.manager.has_service?(svc_id).should eq true
    end

    builder.call

    # Force garbage collection
    10.times{ GC.collect }

    if conn.manager.has_service?(svc_id) # Retry ...
      sleep 0.25
      10.times{ GC.collect }
    end

    conn.manager.has_service?(svc_id).should eq false
  end

  it "supports singleton services" do
    conn = build_connection
    bar = BarClient.new conn

    bar.connection.should eq conn
    bar.service_id.should eq 2u32
    bar.owned?.should eq false
  end

  it "supports singleton services with explicit id" do
    conn = build_connection
    bar = BarClient.new conn, 2u32

    bar.connection.should eq conn
    bar.service_id.should eq 2u32
    bar.owned?.should eq false
  end

  it "supports Connection as only argument" do
    svc = my_service
    svc.tell_me.should eq svc.connection.to_s
  end

  it "supports Connection as last argument" do
    svc = my_service
    svc.tell_me("Hello ").should eq "Hello " + svc.connection.to_s
  end
end
