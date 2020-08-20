class Array

  def +(other)
    res=[]
    each_with_index do |e,i|
      res[i]=e+other[i]
    end
    return res
  end

end
