class Vect
  attr_accessor :x,:y
  def initialize x=nil,y=nil
    @x,@y=x,y
  end

  def to_sexp
    "(Vect #{x} #{y})"
  end

  def to_a
    [x,y]
  end

  def *(scalar)
    Vect.new(@x*scalar,@y*scalar)
  end

  def -(other)
    Vect.new(x-other.x,y-other.y)
  end

  def +(other)
    Vect.new(x+other.x,y+other.y)
  end

  def abs
    Vect.new(x.abs,y.abs)
  end

  def >(other)
    @x > other.x and @y>other.y
  end

  def <(other)
    @x < other.x and @y<other.y
  end
end

class Point < Vect
end

ZERO=Vect.new(0,0)
BORDER=Vect.new(10,10)
MIN_BLOCK=Vect.new(25,25)
