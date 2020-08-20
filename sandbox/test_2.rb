require 'gtk3'

class Canvas < Gtk::DrawingArea
  def initialize
    super()
    signal_connect('draw') do
        on_expose
    end
  end

  def on_expose
    cr = window.create_cairo_context
    cr.set_line_width(0.5)

    w = allocation.width
    h = allocation.height

    cr.translate(w/2, h/2)
    cr.arc(0, 0, 120, 0, 2*Math::PI)
    cr.stroke

    for i in (1..36)
        cr.save
        cr.rotate(i*Math::PI/36)
        cr.scale(0.3, 1)
        cr.arc(0, 0, 120, 0, 2*Math::PI)
        cr.restore
        cr.stroke
    end
  end
end

class Window < Gtk::Window
  def initialize args={} # I want to show it's possible to pass some args
    super()              # mandatory parenthesis ! otherwise : wrong arguments: Gtk::Window#initialize({})
    set_title 'jcll_3'
    set_default_size 900,600
    set_border_width 10
    set_window_position :center
    set_destroy_callback
    init_ui
    show_all
  end

  def set_destroy_callback
    signal_connect("destroy"){Gtk.main_quit}
  end

  def init_ui
    darea = Canvas.new
    add(darea)
  end
end

window=Window.new
Gtk.main
