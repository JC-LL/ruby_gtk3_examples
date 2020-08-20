require 'sxp'

require_relative 'ast'
require_relative 'coord'

module Bde
  class Parser
    def parse filename
      puts "parsing '#{filename}'"
      sexp=SXP.read IO.read(filename)
      parse_diagram sexp
    end

    def parse_diagram sexp
      sexp.shift if sexp.first==:diagram
      if sexp.first.is_a? String
        name=sexp.shift
      else
        raise "expecting a string as diagram id"
      end
      blocks=[]
      while sexp.any?
        blocks << parse_block(sexp.shift)
      end
      Diagram.new(name,blocks)
    end

    def parse_block sexp
      sexp.shift if sexp.first==:block
      if sexp.first.is_a? String
        name=sexp.shift
      else
        raise "expecting a string as block id"
      end
      pos=parse_pos(sexp.shift)
      size=parse_size(sexp.shift)
      Block.new(name,pos,size)
    end

    def parse_pos sexp
      unless sexp.shift==:pos
        raise "expecting 'pos'"
      end
      Coord.new sexp.shift.to_f,sexp.shift.to_f
    end

    def parse_size sexp
      unless sexp.shift==:size
        raise "expecting 'size'"
      end
      Coord.new sexp.shift.to_f,sexp.shift.to_f
    end
  end
end

if $PROGRAM_NAME==__FILE__
  raise "need a file !" unless filename=ARGV.first
  pp Bde::Parser.new.parse filename
end
