require_relative 'code'

module Bde
  class Diagram
    def to_sexp
      code=Code.new
      code << "(diagram \"#{name}\""
      code.indent=2
      blocks.each {|block| code << block.to_sexp}
      code.indent=0
      code << ")"
      code.finalize
    end
  end

  class Block
    def to_sexp
      code=Code.new
      code << "(block \"#{name}\""
      code.indent=2
      code << "(pos  #{pos.x} #{pos.y})"
      code << "(size #{size.x} #{size.y})"
      code.indent=0
      code << ")"
      code
    end
  end
end
