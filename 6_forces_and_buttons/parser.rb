require 'sxp'
require_relative 'graph'

class Parser
  def parse filename
    puts "parsing '#{filename}'"
    sexp=SXP.read IO.read(filename)
    parse_graph sexp
  end

  def parse_graph sexp
    sexp.shift if sexp.first==:graph
    if sexp.first.is_a? String
      name=sexp.shift
    else
      raise "expecting a string as Graph id"
    end
    nodes,edges=[],[]
    while sexp.any?
      case sexp.first.first
      when :node
        nodes << parse_node(sexp.shift)
      when :edge
        edges << parse_edge(sexp.shift)
      end
    end
    graph=Graph.new(name,nodes,edges)
    return graph
  end

  def parse_node sexp
    sexp.shift
    name=sexp.shift
    pos=parse_pos(sexp.shift)
    [name,pos.first,pos.last]
  end

  def parse_pos sexp
    sexp.shift # 'pos'
    [sexp.shift.to_f,sexp.shift.to_f]
  end

  def parse_edge sexp
    sexp.shift # 'edge'
    [sexp.shift, sexp.shift]
  end
end

#pp Parser.new.parse("line.sexp")
