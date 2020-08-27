require_relative 'code'

module Bde
  class Diagram
    def to_sexp
      code=Code.new
      code << "(diagram \"#{name}\""
      code.indent=2
      grobs.each {|grob| code << grob.to_sexp}
      code.indent=0
      code << ")"
      code.finalize
    end
  end

  class Block
    def to_sexp
      code=Code.new
      code << "(block \"#{id}\""
      code.indent=2
      code << "(pos  #{pos.x} #{pos.y})"
      code << "(size #{size.x} #{size.y})"
      code.indent=0
      code << ")"
      code
    end
  end

  class Port
    def to_sexp
      code=Code.new
      code << "(port \"#{id}\""
      code.indent=2
      code << "(pos  #{pos.x} #{pos.y})"
      code << "(size #{size.x} #{size.y})"
      code.indent=0
      code << ")"
      code
    end
  end

  class Wire
    def to_sexp
      code=Code.new
      code << "(wire \"#{id}\""
      code.indent=2
      ports.each do |port|
        code << port.to_sexp
      end
      code.indent=0
      code << ")"
      code
    end
  end

  class Source
    def to_sexp
      "(source #{block} #{port})"
    end
  end

  class Sink
    def to_sexp
      "(sink #{block} #{port})"
    end
  end


end
