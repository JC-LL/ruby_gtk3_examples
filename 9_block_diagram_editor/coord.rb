class Coord
  attr_accessor :x,:y
  def initialize x=nil,y=nil
    @x,@y=x,y
  end

  def inspect
    "(coord #{x} #{y})"
  end

  def -(other)
    Coord.new(self.x-other.x,self.y-other.y)
  end

  def +(other)
    Coord.new(self.x-other.x,self.y-other.y)
  end

  def abs
    Coord.new(x.abs,y.abs)
  end

  def >(other)
    @x > other.x and @y>other.y
  end

  def <(other)
    @x < other.x and @y<other.y
  end
end

ZERO=Coord.new(0,0)
BORDER=Coord.new(10,10)
MIN_BLOCK=Coord.new(25,25)
