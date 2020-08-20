require 'gtk3'
# the objective of this code is to experiment with :
# - adding a drawing area
# - animate a simple drawing (growing circle)
# - ...with a timer.

DELAY=50

class Drawing < Gtk::DrawingArea
  def initialize
    super()
    @radius=10
    @increment=1
    set_drawing_callback
    set_timer_callcack
  end

  def set_drawing_callback
    signal_connect "draw" do
      on_draw
    end
  end

  def set_timer_callcack
    GLib::Timeout.add(DELAY){on_timer}
  end

  # I expect here a growing circle, but not a disk
  def on_timer
    @radius+=@increment
    @increment*=-1 if @radius==100 or @radius==0
    #on_draw   # NOK : disk drawn. Same context
    queue_draw # OK  : growing circle drawn). New context
  end

  def on_draw
    cr = window.create_cairo_context
    execute_drawing_command cr
  end

  def execute_drawing_command cr
    w = allocation.width    # when resized with mouse, the circle...
    h = allocation.height
    cr.translate w/2, h/2   #.... is always in the center.
    cr.arc 0, 0, @radius, 0, 2*Math::PI
    cr.set_line_width 0.5
    cr.stroke
  end

end

class Window < Gtk::Window
  def initialize args={} # I want to show it's possible to pass some args
    super()              # mandatory parenthesis ! otherwise : wrong arguments: Gtk::Window#initialize({})
    set_title 'jcll_3'
    set_default_size 900,600
    set_window_position :center
    set_destroy_callback
    add @drawing=Drawing.new
    show_all
  end

  def set_destroy_callback
    signal_connect("destroy"){Gtk.main_quit}
  end

end

window=Window.new
Gtk.main
