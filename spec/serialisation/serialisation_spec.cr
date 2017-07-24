require "../spec_helper"

describe "Cannon serialisation" do
  context "simple types" do
    context "fast path" do
      it "works with Int8" do
        en_decode(-123i8, 1).should eq -123i8
      end

      it "works with Int16" do
        en_decode(-12345i16, 2).should eq -12345i16
      end

      it "works with Int32" do
        en_decode(-123456789i32, 4).should eq -123456789i32
      end

      it "works with Int64" do
        en_decode(-1234567890123456789i64, 8).should eq -1234567890123456789i64
      end

      it "works with UInt8" do
        en_decode(254u8, 1).should eq 254u8
      end

      it "works with UInt16" do
        en_decode(60000u16, 2).should eq 60000u16
      end

      it "works with UInt32" do
        en_decode(2999999999u32, 4).should eq 2999999999u32
      end

      it "works with UInt64" do
        en_decode(29999999999999999u64, 8).should eq 29999999999999999u64
      end

      it "works with Float32" do
        en_decode(12.34f32, 4).should eq 12.34f32
      end

      it "works with Float64" do
        en_decode(12.34f64, 8).should eq 12.34f64
      end

      it "works with Bool" do
        en_decode(true, 1).should eq true
        en_decode(false, 1).should eq false
      end

      it "works with Tuple" do
        tuple = { 1, true, 4.5f32 }
        en_decode(tuple, 3 * 4).should eq tuple
      end

      it "works with nested Tuple" do
        tuple = { 1, { true, 8u8 }, 4.5f32 }
        en_decode(tuple, 4 + 1 + 1 + 4).should eq tuple
      end

      it "works with Nil" do
        # Nil is somewhat special, as it's encoded as nothing.  It consumes no
        # data at all on its own.
        en_decode(nil, 0).should eq nil
      end
    end

    context "slow path" do
      it "works with Int8" do
        slow_en_decode(-123i8, 1).should eq -123i8
      end

      it "works with Int16" do
        slow_en_decode(-12345i16, 2).should eq -12345i16
      end

      it "works with Int32" do
        slow_en_decode(-123456789i32, 4).should eq -123456789i32
      end

      it "works with Int64" do
        slow_en_decode(-1234567890123456789i64, 8).should eq -1234567890123456789i64
      end

      it "works with UInt8" do
        slow_en_decode(254u8, 1).should eq 254u8
      end

      it "works with UInt16" do
        slow_en_decode(60000u16, 2).should eq 60000u16
      end

      it "works with UInt32" do
        slow_en_decode(2999999999u32, 4).should eq 2999999999u32
      end

      it "works with UInt64" do
        slow_en_decode(29999999999999999u64, 8).should eq 29999999999999999u64
      end

      it "works with Float32" do
        slow_en_decode(12.34f32, 4).should eq 12.34f32
      end

      it "works with Float64" do
        slow_en_decode(12.34f64, 8).should eq 12.34f64
      end

      it "works with Bool" do
        slow_en_decode(true, 1).should eq true
        slow_en_decode(false, 1).should eq false
      end

      it "works with Nil" do
        # Nil is somewhat special, as it's encoded as nothing.  It consumes no
        # data at all on its own.
        slow_en_decode(nil, 0).should eq nil
      end
    end
  end

  context "complex types" do
    it "works with Slice of simple type" do
      slice = Slice(Int32).new(5){|i| i * i}
      en_decode(slice, 6 * 4).should eq slice
    end

    # it "works with Slice of complex type" do
    #   slice = Slice(String).new(5, &.to_s)
    #   en_decode(slice).should eq slice
    # end

    it "works with String" do
      en_decode("Hello there!", 4 + 12).should eq "Hello there!"
    end

    it "works with Array of simple type" do
      ary = Array(Int32).new
      ary << 1 << 4 << 9
      en_decode(ary, 4 * 4).should eq ary
    end

    it "works with Array of complex type" do
      ary = Array(String).new
      ary << "Have" << "A" << "Nice" << "Day!"
      en_decode(ary, 4 + 8 + 5 + 8 + 8).should eq ary
    end

    it "works with Array of union type" do
      ary = Array(String | Int32).new
      ary << "1+1" << "is" << 2
      en_decode(ary, 4 + 8 + 7 + 5).should eq ary
    end

    it "works with Hash" do
      hsh = { "foo" => "bar" }
      en_decode(hsh, 4 + 7 + 7).should eq hsh
    end

    it "works with a nested Hash" do
      hsh = { "foo" => "bar", "another" => { "it" => "works!" } }
      en_decode(hsh, 4 + 7 + 8 + 11 + 5 + 6 + 10).should eq hsh
    end

    it "works with Range with simple types" do
      en_decode(2..10, 4 + 4 + 1).should eq 2..10
      en_decode(2...10, 4 + 4 + 1).should eq 2...10
    end

    it "works with Range with complex types" do
      a = "Foo"
      b = "Bar"

      en_decode(a..b, 7 + 7 + 1).should eq a..b
      en_decode(a...b, 7 + 7 + 1).should eq a...b
    end

    it "works with StaticArray with simple types" do
      data = StaticArray(Int32, 16).new{|i| i*2}
      en_decode(data, 16*4).should eq data
    end

    it "works with StaticArray with complex types" do
      data = StaticArray(String, 4).new{|i| i.to_s}
      en_decode(data, 4*5).should eq data
    end

  end

  context "union types" do
    it "works with it" do
      a = 5.as(Int32 | String)
      b = "Hola".as(Int32 | String)

      en_decode(a, 5).should eq a
      en_decode(b, 9).should eq b
    end

    it "works with nilable types" do
      a = 5.as(Int32 | Nil)
      b = nil.as(Int32 | Nil)

      en_decode(a, 1 + 4).should eq a
      en_decode(b, 1 + 0).should eq b
    end
  end
end
