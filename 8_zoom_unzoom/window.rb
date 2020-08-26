require 'gtk3'
COL = [0.6,0.3,0.2]

class Point
  attr_accessor :x,:y
  def initialize x,y
    @x,@y=x,y
  end

  def *(scal)
    @x*=scal
    @y*=scal
    self
  end
end

class Rectangle
	attr_accessor :x,:y,:w,:h
	attr_accessor :color
	def initialize x,y,w,h
		@x,@y,@w,@h= x,y,w,h
		@color=COL
	end

	def draw ctx
		ctx.set_source_rgb *color
		ctx.rectangle x,y,w,h
		ctx.fill
	end
end

class Model
  attr_accessor :elements

  def initialize
    @elements=[]
  end

  def self.init window
    model=Model.new
    center_x=window.width/2
    center_y=window.height/2
    for x in -2..2
      for y in -2..2
        model.elements << Rectangle.new(center_x+x*100,center_y+y*100,20,20)
      end
    end
    puts "model created"
    model
  end
end

class Canvas < Gtk::DrawingArea
  attr_accessor :model

  def initialize
    super
    set_size_request(800,100)
    create_callbacks
    @model=Model.new
  end

  def create_callbacks
    add_events      [:leave_notify_mask,
                     :button_press_mask,
                     :scroll_mask,
                     :button_release_mask,
                     :pointer_motion_mask,
                     :pointer_motion_hint_mask]

    signal_connect("draw") do |_,cr|
      width=window.width
      height=window.height
      puts "canvas : #{width}x#{height}"
      clear(cr)
      redraw()
    end

    signal_connect("motion-notify-event") do |widget, event|
      puts "mouse : #{pos(event)}"
		end
  end

  def set_model model
    @model=model
  end

  def pos event
    [event.x,event.y]
  end

  def clear cr
    cr.set_source_rgb(0.1, 0.1, 0.1)
    cr.paint
  end

  def zoom position,factor
    @model.elements.each do |rec|
      rec.x=position.x+(rec.x-position.x)*factor
      rec.y=position.y+(rec.y-position.y)*factor
      rec.w*=factor
      rec.h*=factor
    end
  end

  def redraw
    cr = window.create_cairo_context
    clear cr
    @model.elements.each do |rec|
      rec.draw(cr)
    end
  end
end


class App < Gtk::Window
  def initialize
    super
    set_title 'zoom trials'
    set_default_size 900,600
    set_border_width 10
    set_window_position :center
    hbox = Gtk::Box.new(:horizontal, spacing=6)
    add hbox
    @canvas = Canvas.new

    hbox.pack_start(@canvas,:expand=>true,:fill=> true)
    #...instead of :
    # hbox.add canvas

    vbox   = Gtk::Box.new(:vertical,spacing=6)
    hbox.add vbox

    button = Gtk::Button.new(label:"init model")
    button.signal_connect("clicked"){on_init_model()}
    vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)

    button = Gtk::Button.new(label:"zoom+")
    button.signal_connect("clicked"){on_zoom_clicked(button)}
    vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)

    button = Gtk::Button.new(label:"zoom-")
    button.signal_connect("clicked"){on_unzoom_clicked(button)}
    vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)

    button = Gtk::Button.new(:label => "quit")
    button.signal_connect("clicked"){on_quit_clicked(button)}
    vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)
    show_all
  end

  def on_init_model
    canvas_window=@canvas.window
    @model=Model.init(canvas_window)
    @canvas.set_model @model
    @canvas.redraw
  end

  def on_zoom_clicked button
    zoom_position=Point.new(@canvas.window.width/2,@canvas.window.height/2)
    zoom_factor=1.2
    puts "zoom+"
    @canvas.zoom zoom_position,zoom_factor
    @canvas.redraw
  end

  def on_unzoom_clicked button
    zoom_position=Point.new(@canvas.window.width/2,@canvas.window.height/2)
    zoom_factor=0.8
    puts "zoom-"
    @canvas.zoom zoom_position,zoom_factor
    @canvas.redraw
  end

  def on_quit_clicked button
    puts "Closing application"
    Gtk.main_quit
  end

  def set_destroy_callback
    signal_connect("destroy"){Gtk.main_quit}
  end
end

App.new
Gtk.main
