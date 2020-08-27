class Vector
  attr_accessor :x,:y
  def initialize x=nil,y=nil
    @x,@y=x,y
  end

  def to_sexp
    "(vector #{x} #{y})"
  end

  def to_a
    [x,y]
  end

  def *(scalar)
    Vector.new(@x*scalar,@y*scalar)
  end

  def -(other)
    Vector.new(x-other.x,y-other.y)
  end

  def +(other)
    Vector.new(x+other.x,y+other.y)
  end

  def abs
    Vector.new(x.abs,y.abs)
  end

  def >(other)
    @x > other.x and @y>other.y
  end

  def <(other)
    @x < other.x and @y<other.y
  end
end

ZERO=Vector.new(0,0)
BORDER=Vector.new(10,10)
MIN_BLOCK=Vector.new(25,25)
