require "../spec_helper"

struct Slow
  include Cannon::Auto

  property a_string : String
  property an_union : String | Int32
  property an_int : Int32

  def initialize(@a_string, @an_union, @an_int)
  end
end

@[Packed]
struct Fast
  include Cannon::FastAuto

  property a : Int32
  property b : Bool
  property was_fast : Bool

  def initialize(@a, @b, @was_fast)
  end

  def self.from_cannon_io(io)
    a = Cannon.decode io, Int32
    b = Cannon.decode io, Bool
    _dummy = Cannon.decode io, Bool

    new(a, b, false)
  end
end

describe "custom data structures" do
  context "fast path" do
    it "works with a simple structure" do
      fast = Fast.new(a: 123, b: true, was_fast: true)
      en_decode(fast, sizeof(Fast)).should eq fast
    end
  end

  context "slow path" do
    it "works with a complex structure" do
      slow = Slow.new(a_string: "Hello", an_union: 4, an_int: 5)
      en_decode(slow, 9 + 5 + 4).should eq slow
      slow_en_decode(slow, 9 + 5 + 4).should eq slow
    end

    it "works with a simple structure" do
      fast = Fast.new(a: 123, b: true, was_fast: true)
      decoded = slow_en_decode(fast, sizeof(Fast))

      decoded.a.should eq 123
      decoded.b.should eq true
      decoded.was_fast.should eq false
    end
  end
end
