# frozen_string_literal: false
require 'test/unit'

class TestNumeric < Test::Unit::TestCase
  def test_coerce
    a, b = 1.coerce(2)
    assert_equal(Fixnum, a.class)
    assert_equal(Fixnum, b.class)

    a, b = 1.coerce(2.0)
    assert_equal(Float, a.class)
    assert_equal(Float, b.class)

    assert_raise(TypeError) { -Numeric.new }

    assert_raise_with_message(TypeError, /can't be coerced into /) {1+:foo}
    assert_raise_with_message(TypeError, /can't be coerced into /) {1&:foo}
    assert_raise_with_message(TypeError, /can't be coerced into /) {1|:foo}
    assert_raise_with_message(TypeError, /can't be coerced into /) {1^:foo}

    EnvUtil.with_default_external(Encoding::UTF_8) do
      assert_raise_with_message(TypeError, /:\u{3042}/) {1+:"\u{3042}"}
      assert_raise_with_message(TypeError, /:\u{3042}/) {1&:"\u{3042}"}
      assert_raise_with_message(TypeError, /:\u{3042}/) {1|:"\u{3042}"}
      assert_raise_with_message(TypeError, /:\u{3042}/) {1^:"\u{3042}"}
    end
    EnvUtil.with_default_external(Encoding::US_ASCII) do
      assert_raise_with_message(TypeError, /:"\\u3042"/) {1+:"\u{3042}"}
      assert_raise_with_message(TypeError, /:"\\u3042"/) {1&:"\u{3042}"}
      assert_raise_with_message(TypeError, /:"\\u3042"/) {1|:"\u{3042}"}
      assert_raise_with_message(TypeError, /:"\\u3042"/) {1^:"\u{3042}"}
    end

    bug10711 = '[ruby-core:67405] [Bug #10711]'
    exp = "1.2 can't be coerced into Fixnum"
    assert_raise_with_message(TypeError, exp, bug10711) { 1 & 1.2 }
  end

  def test_dummynumeric
    a = Class.new(Numeric) do
      def coerce(x); nil; end
    end.new
    assert_raise(TypeError) { -a }
    assert_nil(1 <=> a)
    assert_raise(ArgumentError) { 1 <= a }

    a = Class.new(Numeric) do
      def coerce(x); 1.coerce(x); end
    end.new
    assert_equal(2, 1 + a)
    assert_equal(0, 1 <=> a)
    assert_operator(1, :<=, a)

    a = Class.new(Numeric) do
      def coerce(x); [x, 1]; end
    end.new
    assert_equal(-1, -a)

    bug7688 = '[ruby-core:51389] [Bug #7688]'
    a = Class.new(Numeric) do
      def coerce(x); raise StandardError; end
    end.new
    assert_raise_with_message(TypeError, /can't be coerced into /) { 1 + a }
    warn = /will no more rescue exceptions of #coerce.+ in the next release/m
    assert_warn(warn, bug7688) { assert_raise(ArgumentError) { 1 < a } }

    a = Class.new(Numeric) do
      def coerce(x); :bad_return_value; end
    end.new
    assert_raise_with_message(TypeError, "coerce must return [x, y]") { 1 + a }
    warn = /Bad return value for #coerce.+next release will raise an error/m
    assert_warn(warn, bug7688) { assert_raise(ArgumentError) { 1 < a } }
  end

  def test_singleton_method
    a = Numeric.new
    assert_raise_with_message(TypeError, /foo/) { def a.foo; end }
    assert_raise_with_message(TypeError, /\u3042/) { eval("def a.\u3042; end") }
  end

  def test_dup
    a = Numeric.new
    assert_raise(TypeError) { a.dup }

    c = Module.new do
      break eval("class C\u{3042} < Numeric; self; end")
    end
    assert_raise_with_message(TypeError, /C\u3042/) {c.new.dup}
  end

  def test_quo
    a = Numeric.new
    assert_raise(TypeError) {a.quo(1)}
  end

  def test_quo_ruby_core_41575
    rat = 84.quo(1)
    x = Class.new(Numeric) do
      define_method(:to_r) { rat }
    end.new
    assert_equal(2.quo(1), x.quo(42), '[ruby-core:41575]')
  end

  def test_divmod
=begin
    x = Class.new(Numeric) do
      def /(x); 42.0; end
      def %(x); :mod; end
    end.new

    assert_equal(42, x.div(1))
    assert_equal(:mod, x.modulo(1))
    assert_equal([42, :mod], x.divmod(1))
=end

    assert_kind_of(Integer, 11.divmod(3.5).first, '[ruby-dev:34006]')
  end

  def test_real_p
    assert_predicate(Numeric.new, :real?)
  end

  def test_integer_p
    assert_not_predicate(Numeric.new, :integer?)
  end

  def test_abs
    a = Class.new(Numeric) do
      def -@; :ok; end
      def <(x); true; end
    end.new

    assert_equal(:ok, a.abs)

    a = Class.new(Numeric) do
      def <(x); false; end
    end.new

    assert_equal(a, a.abs)
  end

  def test_zero_p
    a = Class.new(Numeric) do
      def ==(x); true; end
    end.new

    assert_predicate(a, :zero?)
  end

  def test_nonzero_p
    a = Class.new(Numeric) do
      def zero?; true; end
    end.new
    assert_nil(a.nonzero?)

    a = Class.new(Numeric) do
      def zero?; false; end
    end.new
    assert_equal(a, a.nonzero?)
  end

  def test_positive_p
    a = Class.new(Numeric) do
      def >(x); true; end
    end.new
    assert_predicate(a, :positive?)

    a = Class.new(Numeric) do
      def >(x); false; end
    end.new
    assert_not_predicate(a, :positive?)
  end

  def test_negative_p
    a = Class.new(Numeric) do
      def <(x); true; end
    end.new
    assert_predicate(a, :negative?)

    a = Class.new(Numeric) do
      def <(x); false; end
    end.new
    assert_not_predicate(a, :negative?)
  end

  def test_to_int
    a = Class.new(Numeric) do
      def to_i; :ok; end
    end.new

    assert_equal(:ok, a.to_int)
  end

  def test_cmp
    a = Numeric.new
    assert_equal(0, a <=> a)
    assert_nil(a <=> :foo)
  end

  def test_floor_ceil_round_truncate
    a = Class.new(Numeric) do
      def to_f; 1.5; end
    end.new

    assert_equal(1, a.floor)
    assert_equal(2, a.ceil)
    assert_equal(2, a.round)
    assert_equal(1, a.truncate)

    a = Class.new(Numeric) do
      def to_f; 1.4; end
    end.new

    assert_equal(1, a.floor)
    assert_equal(2, a.ceil)
    assert_equal(1, a.round)
    assert_equal(1, a.truncate)

    a = Class.new(Numeric) do
      def to_f; -1.5; end
    end.new

    assert_equal(-2, a.floor)
    assert_equal(-1, a.ceil)
    assert_equal(-2, a.round)
    assert_equal(-1, a.truncate)
  end

  def assert_step(expected, (from, *args), inf: false)
    enum = from.step(*args)
    size = enum.size
    xsize = expected.size

    if inf
      assert_send [size, :infinite?], "step size: +infinity"
      assert_send [size, :>, 0], "step size: +infinity"

      a = []
      from.step(*args) { |x| a << x; break if a.size == xsize }
      assert_equal expected, a, "step"

      a = []
      enum.each { |x| a << x; break if a.size == xsize }
      assert_equal expected, a, "step enumerator"
    else
      assert_equal expected.size, size, "step size"

      a = []
      from.step(*args) { |x| a << x }
      assert_equal expected, a, "step"

      a = []
      enum.each { |x| a << x }
      assert_equal expected, a, "step enumerator"
    end
  end

  def test_step
    i, bignum = 32, 1 << 30
    bignum <<= (i <<= 1) - 32 until bignum.is_a?(Bignum)
    assert_raise(ArgumentError) { 1.step(10, 1, 0) { } }
    assert_raise(ArgumentError) { 1.step(10, 1, 0).size }
    assert_raise(ArgumentError) { 1.step(10, 0) { } }
    assert_raise(ArgumentError) { 1.step(10, 0).size }
    assert_raise(ArgumentError) { 1.step(10, "1") { } }
    assert_raise(ArgumentError) { 1.step(10, "1").size }
    assert_raise(TypeError) { 1.step(10, nil) { } }
    assert_raise(TypeError) { 1.step(10, nil).size }
    assert_nothing_raised { 1.step(by: 0, to: nil) }
    assert_nothing_raised { 1.step(by: 0, to: nil).size }
    assert_nothing_raised { 1.step(by: 0) }
    assert_nothing_raised { 1.step(by: 0).size }
    assert_nothing_raised { 1.step(by: nil) }
    assert_nothing_raised { 1.step(by: nil).size }

    bug9811 = '[ruby-dev:48177] [Bug #9811]'
    assert_raise(ArgumentError, bug9811) { 1.step(10, foo: nil) {} }
    assert_raise(ArgumentError, bug9811) { 1.step(10, foo: nil).size }
    assert_raise(ArgumentError, bug9811) { 1.step(10, to: 11) {} }
    assert_raise(ArgumentError, bug9811) { 1.step(10, to: 11).size }
    assert_raise(ArgumentError, bug9811) { 1.step(10, 1, by: 11) {} }
    assert_raise(ArgumentError, bug9811) { 1.step(10, 1, by: 11).size }

    assert_equal(bignum*2+1, (-bignum).step(bignum, 1).size)
    assert_equal(bignum*2, (-bignum).step(bignum-1, 1).size)

    assert_equal(10+1, (0.0).step(10.0, 1.0).size)

    i, bigflo = 1, bignum.to_f
    i <<= 1 until (bigflo - i).to_i < bignum
    bigflo -= i >> 1
    assert_equal(bigflo.to_i, (0.0).step(bigflo-1.0, 1.0).size)
    assert_operator((0.0).step(bignum.to_f, 1.0).size, :>=, bignum) # may loose precision

    assert_step [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], [1, 10]
    assert_step [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], [1, to: 10]
    assert_step [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], [1, to: 10, by: nil]
    assert_step [1, 3, 5, 7, 9], [1, 10, 2]
    assert_step [1, 3, 5, 7, 9], [1, to: 10, by: 2]

    assert_step [10, 8, 6, 4, 2], [10, 1, -2]
    assert_step [10, 8, 6, 4, 2], [10, to: 1, by: -2]
    assert_step [1.0, 3.0, 5.0, 7.0, 9.0], [1.0, 10.0, 2.0]
    assert_step [1.0, 3.0, 5.0, 7.0, 9.0], [1.0, to: 10.0, by: 2.0]
    assert_step [1], [1, 10, bignum]
    assert_step [1], [1, to: 10, by: bignum]

    assert_step [], [2, 1, 3]
    assert_step [], [-2, -1, -3]
    assert_step [3, 3, 3, 3], [3, by: 0], inf: true
    assert_step [3, 3, 3, 3], [3, by: 0, to: 42], inf: true
    assert_step [10], [10, 1, -bignum]

    assert_step [], [1, 0, Float::INFINITY]
    assert_step [], [0, 1, -Float::INFINITY]
    assert_step [10], [10, to: 1, by: -bignum]

    assert_step [10, 11, 12, 13], [10], inf: true
    assert_step [10, 9, 8, 7], [10, by: -1], inf: true
    assert_step [10, 9, 8, 7], [10, by: -1, to: nil], inf: true

    assert_step [42, 42, 42, 42], [42, by: 0, to: -Float::INFINITY], inf: true
    assert_step [42, 42, 42, 42], [42, by: 0, to: 42.5], inf: true
    assert_step [4.2, 4.2, 4.2, 4.2], [4.2, by: 0.0], inf: true
    assert_step [4.2, 4.2, 4.2, 4.2], [4.2, by: -0.0], inf: true
    assert_step [42.0, 42.0, 42.0, 42.0], [42, by: 0.0, to: 44], inf: true
    assert_step [42.0, 42.0, 42.0, 42.0], [42, by: 0.0, to: 0], inf: true
    assert_step [42.0, 42.0, 42.0, 42.0], [42, by: -0.0, to: 44], inf: true

    assert_step [bignum]*4, [bignum, by: 0], inf: true
    assert_step [bignum]*4, [bignum, by: 0.0], inf: true
    assert_step [bignum]*4, [bignum, by: 0, to: bignum+1], inf: true
    assert_step [bignum]*4, [bignum, by: 0, to: 0], inf: true
  end

  def test_num2long
    assert_raise(TypeError) { 1 & nil }
    assert_raise(TypeError) { 1 & 1.0 }
    assert_raise(TypeError) { 1 & 2147483648.0 }
    assert_raise(TypeError) { 1 & 9223372036854777856.0 }
    o = Object.new
    def o.to_int; 1; end
    assert_raise(TypeError) { assert_equal(1, 1 & o) }
  end

  def test_eql
    assert_equal(1, 1.0)
    assert_not_operator(1, :eql?, 1.0)
    assert_not_operator(1, :eql?, 2)
  end

  def test_coerced_remainder
    assert_separately([], <<-'end;')
      x = Class.new do
        def coerce(a) [self, a]; end
        def %(a) self; end
      end.new
      assert_raise(ArgumentError) {1.remainder(x)}
    end;
  end
end
