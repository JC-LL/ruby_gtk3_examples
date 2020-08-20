
class Canvas < Gtk::DrawingArea
  attr_accessor :running
  def initialize
    super()

    @running=false
    set_size_request(800,100)
    signal_connect('draw') do
      redraw @graph
    end
  end

  def clear cr
    cr.set_source_rgb(0.1, 0.1, 0.1)
    cr.paint
  end

  def redraw graph=nil,zoom_factor=1,shift=Vector.new(0,0)
    @graph=graph
    cr = window.create_cairo_context
    cr.set_line_width(0.8)

    w = allocation.width
    h = allocation.height

    cr.translate(w/2, h/2)

    clear cr

    if graph
      cr.set_source_rgb(0.4, 0.4, 0.4)
      @graph.edges.each do |edge|
        n1,n2=*edge
        cr.move_to(shift.x + n1.x*zoom_factor,shift.y + n1.y*zoom_factor)
        cr.line_to(shift.x + n2.x*zoom_factor,shift.y + n2.y*zoom_factor)
        cr.stroke
      end

      cr.set_source_rgb(0.9, 0.5, 0.2)
      @graph.nodes.each do |node|
        cr.arc(shift.x+node.x*zoom_factor, shift.y+node.y*zoom_factor, 10*zoom_factor, 0, 2.0 * Math::PI)
        cr.fill_preserve()
        cr.stroke
      end
    end

  end
end
