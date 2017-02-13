require "../spec_helper"

describe Cannon::Rpc::Manager do
  describe "#add" do
    it "adds the service" do
      mgr = build_manager
      foo = FooService.new

      id = mgr.add(foo)
      id.should eq 0u32

      foo.manager.should eq mgr
      foo.owner.should eq nil
      foo.service_id.should eq id
      mgr[id].should eq foo
    end

    it "adds the service using the specified id" do
      mgr = build_manager
      foo = FooService.new

      id = mgr.add(foo, id: 123u32)
      id.should eq 123u32

      foo.manager.should eq mgr
      foo.owner.should eq nil
      foo.service_id.should eq 123u32
      mgr[123u32].should eq foo
    end

    it "sets the owner" do
      mgr = build_manager
      conn = build_connection(mgr)
      foo = FooService.new

      id = mgr.add(foo, owner: conn)
      id.should eq 0u32

      foo.manager.should eq mgr
      foo.owner.should eq conn
      foo.service_id.should eq id
      mgr[id].should eq foo
    end

    it "raises if the service is already in use" do
      mgr = build_manager

      expect_raises(ArgumentError) do
        mgr.add(mgr[1u32])
      end
    end

    it "finds an unused id" do
      mgr = build_manager
      first = FooService.new
      second = FooService.new

      mgr.add(first).should eq 0u32
      mgr.add(second).should eq 3u32
    end

    it "recycles unused ids at some point" do
      mgr = build_manager

      services = Array(FooService).new(10){ FooService.new }
      services.each{|svc| mgr.add svc}
      services.each{|svc| mgr.release svc}

      mgr.has_service?(0u32).should eq false
      mgr.has_service?(1u32).should eq true
      mgr.has_service?(2u32).should eq true
      mgr.has_service?(3u32).should eq false

      mgr.add(FooService.new).should eq 0u32
      mgr.has_service?(0u32).should eq true
    end

    context "if it's a singleton service" do
      context "and NO explicit id is given" do
        it "uses the singleton service id" do
          mgr = build_manager
          bar = BarService.new

          id = mgr.add(bar)
          id.should eq 2u32

          bar.manager.should eq mgr
          bar.owner.should eq nil
          bar.service_id.should eq id
          mgr[id].should eq bar
        end
      end

      context "and an explicit id is given" do
        it "uses the explicit service id" do
          mgr = build_manager
          bar = BarService.new

          id = mgr.add(bar, id: 123u32)
          id.should eq 123u32

          bar.manager.should eq mgr
          bar.owner.should eq nil
          bar.service_id.should eq 123u32
          mgr[123u32].should eq bar
        end
      end
    end
  end

  describe "#release" do
    context "if the owner matches" do
      it "removes the service" do
        mgr = build_manager
        conn = build_connection(mgr)
        foo = FooService.new

        id = mgr.add(foo, conn)
        mgr.has_service?(id).should eq true

        mgr.release id, owner: conn
        mgr.has_service?(id).should eq false
      end
    end

    context "if the owner does NOT match" do
      it "raises an error" do
        mgr = build_manager
        conn = build_connection(mgr)
        foo = FooService.new

        id = mgr.add(foo, owner: nil)
        mgr.has_service?(id).should eq true

        expect_raises(Cannon::Rpc::Error) do
          mgr.release id, owner: conn
        end

        mgr.has_service?(id).should eq true
      end
    end
  end

  describe "#has_service?" do
    context "if the service exists" do
      it "returns true" do
        build_manager.has_service?(1u32).should eq true
      end
    end

    context "if the does NOT service exist" do
      it "returns false" do
        build_manager.has_service?(0u32).should eq false
      end
    end
  end
end
