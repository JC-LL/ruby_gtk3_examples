module Bde
  class Diagram
    attr_accessor :name,:blocks
    def initialize name,blocks=[]
      @name,@blocks=name,blocks
    end
  end

  class Block
    attr_accessor :name,:pos,:size
    def initialize name,pos,size
      @name,@pos,@size=name,pos,size
    end
  end
end
