require_relative 'vector'
require_relative 'parser'

class Node
  attr_accessor :pos,:id,:radius,:velocity
  def initialize params
    @id=params.first
    @pos=Vector.new params[1],params[2]
    @radius=params[3] || 10
    @velocity = (params.size>4) ? Vector.new(params[4],params[5]) :  Vector.new(0,0)
  end

  def x=(v)
    @pos[0]=v
  end

  def y=(v)
    @pos[1]=v
  end

  def x
    @pos.first
  end

  def y
    @pos.last
  end

  def print_info
    pp "node #{@id} : pos=#{@pos},radius=#{@radius},v=#{@velocity}"
  end
end

# nodes are passed as [[:id,x,y],...]
# connections as : [:b,:c], [:a,:b]...
class Graph

  attr_accessor :nodes,:id,:edges,:map

  def initialize id,nodes=[],edges=[]
    @id=id
    @map={}
    @nodes=nodes.collect do |sexp|
      node=Node.new(sexp)
      @map[sexp.first]=node
      node
    end
    @edges=edges.collect do |e|
      [@map[e.first],@map[e.last]]
    end
  end

  def self.read_file filename
    Parser.new.parse filename
  end

  def write_file filename
    puts "write '#{filename}'"
    code=""
    code << "(graph \"#{@id}\"\n"
    nodes.each do |node|
      code << "  (node \"#{node.id}\" (pos #{node.pos[0]} #{node.pos[1]}))\n"
    end
    code << "\n"
    edges.each do |edge|
      code << "  (edge \"#{edge.first.id}\" \"#{edge.last.id}\")\n"
    end
    code << ")\n"
    File.open(filename ,'w'){|f| f.puts code}
  end

  def self.random(nbVertex,maxNbEdgesPerVertex=2)
    nodes,edges =[],[]

    (1..nbVertex).each do |i|
      id = "n#{i}".to_sym
      pos = self.random_pos
      radius = self.rand_between(10,20)
      params = [id,pos,radius].flatten
      nodes << params
    end

    nodes.each do |node|
      nbEdges=(1..maxNbEdgesPerVertex).to_a.sample
      others = nodes - [node]
      toConnect = others.sample(nbEdges)
      toConnect.each do |nj|
        edges << [node.first,nj.first]
      end
    end
    return Graph.new :random,nodes,edges
  end

  def shuffle range=0..800
    nodes.each do |node|
      node.pos=Vector.new *Graph.random_pos
    end
  end

  def print_info
    puts "graph info".center(40,"=")
    puts "#vertices".ljust(30,'.')+nodes.size.to_s
    puts "#edges".ljust(30,'.')+edges.size.to_s
    nodes.each do |ni|
      neighbours=edges.select{|e| e.first==ni}.collect{|tab| tab.last.id}
      puts "#{ni.id} --> #{neighbours}"
    end
  end

  def self.rand_between min,max
    (min..max).to_a.sample
  end

  def self.random_pos(maxx=800,maxy=600)
    x,y=maxx/2,maxy/2
    [self.rand_between(-x,x),self.rand_between(-y,y)]
  end

  def each_vertex &block
    @nodes.each do |node|
      yield node
    end
  end

  def each_edge &block
    @edges.each do |edge|
      yield edge
    end
  end

end

# g=Graph.new(:test,
#             [
#              [:a,0,0],
#              [:b,10,0],
#              [:c,0,20]
#             ],
#             [
#              [:a,:b],
#              [:b,:c],
#              [:a,:c]
#             ])
# g.printInfo

# g=Graph.new(:test,
#             [
#              [:a,0,0],
#              [:b,10,0],
#              [:c,0,20],
#              [:d,0,0],
#              [:e,0,0]
#             ],
#             [
#              [:a,:b],
#              [:b,:c],
#              [:a,:c],
#              [:c,:e],
#              [:e,:d],
#              [:a,:d]
#             ])
# g.printInfo

# g=Graph.random 10,4
# g.printInfo
