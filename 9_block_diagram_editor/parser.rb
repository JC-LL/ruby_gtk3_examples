require 'sxp'

require_relative 'ast'
require_relative 'vector'

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
      blocks,ports=[],[]
      while sexp.any?
        case sexp.first.first
        when :block
          blocks << parse_block(sexp.shift)
        when :port
          ports << parse_port(sexp.shift)
        end
      end
      Diagram.new(name,blocks,ports)
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

    def parse_port sexp
      sexp.shift if sexp.first==:port
      if sexp.first.is_a? String
        name=sexp.shift
      else
        raise "expecting a string as port id"
      end
      pos=parse_pos(sexp.shift)
      size=parse_size(sexp.shift)
      Port.new(name,pos,size)
    end

    def parse_pos sexp
      unless sexp.shift==:pos
        raise "expecting 'pos'"
      end
      Vector.new sexp.shift.to_f,sexp.shift.to_f
    end

    def parse_size sexp
      unless sexp.shift==:size
        raise "expecting 'size'"
      end
      Vector.new sexp.shift.to_f,sexp.shift.to_f
    end
  end
end

if $PROGRAM_NAME==__FILE__
  raise "need a file !" unless filename=ARGV.first
  pp Bde::Parser.new.parse filename
end
