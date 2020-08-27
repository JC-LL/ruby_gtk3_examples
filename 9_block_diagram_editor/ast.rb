module Bde

  class Diagram
    attr_accessor :name,:blocks,:ports
    def initialize name,blocks=[],ports=[]
      @name,@blocks,@ports=name,blocks,ports
    end

    def grobs
      [blocks,ports].flatten
    end
  end

  class Grob
    attr_accessor :name,:pos,:size
    def initialize name,pos,size
      @name,@pos,@size=name,pos,size
    end
  end

  class Block < Grob
  end

  class Port < Grob
  end
end
