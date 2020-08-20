require_relative 'graph'
require_relative 'vector'

class ForceDirectedGraphDrawer

  attr_accessor :graph
  attr_accessor :stop
  def initialize
    puts "FDGD: force-directed graph drawer"
    @l0=80
    @c1=30
    @epsilon=10
    @damping=0.92
    @timestep=0.1
    @stop=false
  end

  def dist a,b
    Math.sqrt((a.x - b.x)**2 + (a.y - b.y)**2)
  end

  def angle a,b
    if dist(a,b)!=0
      if b.x > a.x
        angle = Math.asin((b.y-a.y)/dist(a,b))
      else
        angle = Math::PI - Math.asin((b.y-a.y)/dist(a,b))
      end
    else
      angle =0
    end
    return angle
  end

  def coulomb_repulsion a,b
    angle = angle(a,b)
    dab = dist(a,b)
    c= -0.2*(a.radius*b.radius)/Math.sqrt(dab)
    [c*Math.cos(angle),c*Math.sin(angle)]
  end

  def sign_minus(a,b)
    a>b ? 1 : -1
  end

  def hooke_attraction a,b #,c1=10#,l0=40
    angle = angle(a,b)
    dab = dist(a,b)
    c = @c1*Math.log((dab-@l0).abs)*sign_minus(dab,@l0)
    [c*Math.cos(angle),c*Math.sin(angle)]
  end

  def run iter=2
    if @graph
      Thread.new do
        step = 0
        total_kinetic_energy=1000
        next_pos={}

        until total_kinetic_energy < @epsilon or step==iter do

          step+=1
          total_kinetic_energy = 0

          for node in graph.nodes
            net_force = Vector.new(0, 0)

            for other in graph.nodes-[node]
              rep = coulomb_repulsion( node, other)
              net_force += rep
            end

            for edge in graph.edges.select{|e| e.first==node or e.last==node}
              other = edge.last==node ? edge.first : edge.last
              attr = hooke_attraction(node, other) #, c1=30,@l0)
              net_force += attr
            end

            # without damping, it moves forever
            node.velocity = (node.velocity + net_force.scale(@timestep)).scale(@damping)
            next_pos[node.pos] = node.pos + node.velocity.scale(@timestep)
            total_kinetic_energy += node.radius * node.velocity.squared
          end

          #puts total_kinetic_energy
          yield if block_given?
          for node in graph.nodes
            node.pos = next_pos[node.pos]
          end
          break if @stop
        end
        puts "algorithm end"
        puts "reached epsilon" if total_kinetic_energy < @epsilon
        puts "reached max iterations" if step==iter
      end #thread
    end
  end

end
