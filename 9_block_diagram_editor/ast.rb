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
    attr_accessor :ports
    def initialize id,pos,size
      super(id,pos,size)
      @ports=[]
    end
  end

  class Port < Grob
  end

  class Handle < Grob
  end

  class Wire < Grob
    attr_accessor :id,:ports
    def initialize id,ports
      super(id,ports.first.pos,ZERO)
      @id,@ports=id,ports
    end

    def points
      ret=[]
      source=ports.first
      ret << source.pos+Vector.new(source.size.x,source.size.y/2)
      ret << ports[1..-1].map{|port| port.pos+Vector.new(0,port.size.y/2)}
      ret.flatten
    end
  end

  class Source
    attr_accessor :block,:port
    def initialize block,port
      @block,@port=block,port
    end
  end

  class Sink
    attr_accessor :block,:port
    def initialize block,port
      @block,@port=block,port
    end
  end

  class Segment
    attr_accessor :id,:source,:sink
    def initialize id,source,sink
      @id,@source,@sink=id,source,sink
    end
  end


end
