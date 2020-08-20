class Vector
  def initialize x=nil,y=nil
    @array=[x,y]
  end

  def x
    return @array[0]
  end

  def y
    return @array[1]
  end

  def first
    @array.first
  end

  def last
    @array.last
  end

  def [](idx)
    @array[idx]
  end

  def []=(idx,val)
    @array[idx]=val
  end

  def +(other)
    res=Vector.new
    @array.each_with_index do |e,i|
      res[i]=e + other[i]
    end
    return res
  end

  def scale int
    res=Vector.new
    @array.each_with_index do |e,i|
      res[i]=e*int
    end
    return res
  end

  def squared
    res=0
    @array.each do |e|
      res+=e*e
    end
    return res
  end

end
