module Bde

  class Diagram
    attr_accessor :name,:blocks,:ports,:wires
    def initialize name,blocks=[],ports=[],wires=[]
      @name,@blocks,@ports,@wires=name,blocks,ports,wires
    end

    def grobs
      [blocks,ports,wires].flatten
    end
  end

  class Grob
    attr_accessor :id,:pos,:size
    def initialize id,pos,size
      @id,@pos,@size=id,pos,size
    end
  end

  class Block < Grob
  end

  class Port < Grob
  end

  class Connection < Grob
    attr_accessor :source,:sink
    def initialize id,psource,psink,wire=nil
      super(name,psource.pos,ZERO)
      @source = psource
      @sink   = psink
      @wire   = wire
    end
  end

  class Wire < Grob
    attr_accessor :name,:points
    def initialize id,*points
      super(name,points.first,ZERO)
      @points=[]
      @points << points
      @points.flatten!
    end
  end
end
