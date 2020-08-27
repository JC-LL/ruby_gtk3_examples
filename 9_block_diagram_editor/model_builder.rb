module Bde
  class ModelBuilder
    def build_from ast
      build_symbol_table(ast)
      relink_semantic(ast)
      pp ast
      return ast
    end

    def build_symbol_table ast
      puts "building symbol table"
      @symtable={}
      ast.ports.each do |port|
        @symtable[port.id]=port
      end
      ast.blocks.each do |block|
        @symtable[block.id]=block
        block.ports.each do |port|
          @symtable[port.id]=port
        end
      end
    end

    def relink_semantic ast
      puts "semantic linking"
      ast.wires.each do |wire|
        wire.ports=wire.ports.map{|port| @symtable[port.id]}
      end
    end
  end
end
