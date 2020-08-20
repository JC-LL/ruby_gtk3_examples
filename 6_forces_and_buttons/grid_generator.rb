require_relative 'graph'

class GridGenerator
  def self.generate n=10,m=5
    graph=Graph.new name="grid_#{n}_#{m}"
    grid=Array.new(n){Array.new(m){nil}}
    for i in 0..n-1
      for j in 0..m-1
        params=["node_#{i}_#{j}",rand(0..n*10),rand(0..m*10)]
        graph.nodes << grid[i][j]=Node.new(params)
      end
    end
    for i in 0..n-1
      for j in 0..m-1
        if grid[i+1]
          graph.edges << [grid[i][j],grid[i+1][j]]
        end
        if grid[i][j+1]
          graph.edges << [grid[i][j],grid[i][j+1]]
        end
      end
    end
    graph.write_file "#{name}.sexp"
  end
end

GridGenerator.generate *(ARGV.map(&:to_i))
