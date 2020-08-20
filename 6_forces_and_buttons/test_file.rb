require_relative 'graph'

graph=Graph.read_file "circle.sexp"
graph.write_file "circle_wr.sexp"
