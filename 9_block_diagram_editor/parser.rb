require 'sxp'

require_relative 'ast'
require_relative 'vector'

module Bde
  class Parser
    def parse filename
      puts "parsing '#{filename}'"
      sexp=SXP.read IO.read(filename)
      ast=parse_diagram(sexp)
      pp ast
      return ast
    end

    def parse_diagram sexp
      sexp.shift if sexp.first==:diagram
      if sexp.first.is_a? String
        name=sexp.shift
      else
        raise "expecting a string as diagram id"
      end
      blocks,ports,wires=[],[],[]
      while sexp.any?
        case sexp.first.first
        when :block
          blocks << parse_block(sexp.shift)
        when :port
          ports << parse_port(sexp.shift)
        when :wire
          wires << parse_wire(sexp.shift)
        end
      end
      Diagram.new(name,blocks,ports,wires)
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

    def parse_wire sexp
      sexp.shift if sexp.first==:wire
      if sexp.first.is_a? String
        id=sexp.shift
      else
        raise "expecting a string as wire id"
      end
      ports,handles,segments=[],[],[]
      while sexp.any?
        case first=sexp.first.first
        when :port
          ports << parse_port(sexp.shift)
        when :handle
          handles << parse_handle(sexp.shift)
        when :segment
          segments << parse_segment(sexp.shift)
        else
          raise "syntaxe error : unknow type '#{first}'"
        end
      end
      Wire.new(id,ports)
    end

    def parse_source sexp
      unless sexp.shift==:source
        raise "expecting 'source'"
      end
      Source.new(sexp.shift,sexp.shift)
    end

    def parse_sink sexp
      unless sexp.shift==:sink
        raise "expecting 'sink'"
      end
      Sink.new(sexp.shift,sexp.shift)
    end

    def parse_handle sexp
      sexp.shift if sexp.first==:handle
      if sexp.first.is_a? String
        id=sexp.shift
      else
        raise "expecting a string as handle id"
      end
      pos=parse_pos(sexp.shift)
      size=parse_size(sexp.shift)
      Handle.new(id,pos,size)
    end

    def parse_segment sexp
      sexp.shift if sexp.first==:segment
      if sexp.first.is_a? String
        id=sexp.shift
      else
        raise "expecting a string as segment id"
      end
      source=parse_source(sexp.shift)
      sink  =parse_sink(sexp.shift)
      Segment.new(id,source,sink)
    end

    def parse_point sexp
      unless sexp.shift==:point
        raise "expecting 'pos'"
      end
      Vector.new sexp.shift.to_f,sexp.shift.to_f
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
