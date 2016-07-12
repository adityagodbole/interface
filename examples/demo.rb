# run as `RUBY_INTERFACE_TYPECHECK= 1 ruby examples/demo.rb`
require_relative '../lib/interface'

Adder = interface {
  # sum is a method that takes an array of Integer and returns an Integer
  proto(:sum, [Integer]) { Integer }
}

Calculator = interface {
  # interfaces can be composed
  extends Adder
  # method fact takes an Integer and returns an Integer
  proto(:fact, Integer) { Integer }
  # method pos takes an array of Integers, an Integer, and returns either Integer or nil
  proto(:pos, [Integer], Integer) { [Integer, NilClass].to_set }
}

class SimpleCalc
  def fact(n)
    (2..n).reduce(1) { |m, e| m * e }
  end

  def sum(a)
    a.reduce(0, &:+)
  end

  def pos(arr, i)
    arr.index(i)
  end

  implements Calculator #, runtime_checks: false # default is true
end

c = SimpleCalc.new
# If SimpleCalc does not have `implements Calculator`, but its methods match the interface
# you can "cast" it to Calculator - `SimpleCalc.as_interface(Calculator).new`
# This is useful for casting classes that you did not write
p c.sum([1, 2])
p c.pos([1, 2, 3], 4)

AdvancedCalculator = interface {
  extend Calculator
  proto(:product, Integer, Integer) { Integer }
}

module AdvancedCalcT
  extend Interface::Trait
  def product(a, b)
    ret = 0
    a.times { ret = sum([ret, b]) }
    ret
  end

  def sum; end # A class method always takes precedence, no conflict here
  def foo; end # this conflicts with DummyCalcT. Needs to be aliased (see below)
  def bar; end # this conflicts with DummyCalcT. Needs to be aliased (see below)

  requires_interface Adder # Note that this will give an error if SimpleCalc#sum is removed
                           # even if this trait itself has a `sum` method
end

module DummyCalcT
  extend Interface::Trait
  def sum; end # this method conflicts with AdvancedCalcT, but SimpleCalc#sum takes precedence
  def foo; end
  def bar; end
  class << self
    def included(_)
      $stderr.puts "Works like a regular module as well"
    end
  end
end

# This is how we compose behaviours
# AdvancedCalc is a class which mixes traits AdvancedCalcT and DummyCalcT
# into SimpleCalc and implements the interface AdvancedCalculator
# To avoid conflicts, alias methods in AdvancedCalcT (otherwise error will be raised)
# One can also suppress methods in DummyCalcT
AdvancedCalc = SimpleCalc.with_trait(AdvancedCalcT,
                                     aliases: { foo: :adfoo, bar: :adbar })
                         .with_trait(DummyCalcT, suppresses: [:foo, :bar])
                         .as_interface(AdvancedCalculator)

sc = AdvancedCalc.new
p sc.product(3, 2)

__END__

# Benchmarks. Run with RUBY_INTERFACE_TYPECHECK=0 and 1 to compare

t1 = Time.now
1_000_000.times do
  c.fact(50)
end
t2 = Time.now

p t2 - t1
