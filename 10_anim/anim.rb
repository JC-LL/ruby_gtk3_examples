require 'gtk3'
require 'pango'
require 'cairo'
class AnimationWindow < Gtk::Window
  def initialize
    super

    set_title 'Gtk3 Animation'
    signal_connect('destroy') { Gtk.main_quit }

    # Set the size of the window (width, height)
    set_default_size(800, 600)

    @drawing_area = Gtk::DrawingArea.new
    add(@drawing_area)

    @current_frame = 0
    @total_frames = 400
    @animation_timer = nil

    init_animation# Connect the "draw" signal to the draw_frame method
    @drawing_area.signal_connect('draw') do |widget, context|
      draw_frame(widget, context)
    end
  end

  def init_animation
    @animation_timer = GLib::Timeout.add(50) do # Timer interval in milliseconds (100ms = 0.1 seconds)
      @current_frame += 1
      @current_frame %= @total_frames
      @drawing_area.queue_draw # Request a redraw of the drawing area
      true # Keep the timer running
    end
  end


  def draw_frame(widget, context)
    width = widget.allocated_width
    height = widget.allocated_height

    # Clear the drawing area
    context.set_source_rgb(1.0, 1.0, 1.0) # Set the fill color to white
    context.rectangle(0, 0, width, height)
    context.fill

    # Draw a moving rectangle
    rect_width = 50
    rect_height = 50
    x = (@current_frame % (width - rect_width)).to_i
    y = height / 2 - rect_height / 2

    context.set_source_rgb(0.5, 0.7, 0.9) # Set the fill color to light blue
    context.rectangle(x, y, rect_width, rect_height)
    context.fill

    # Draw a moving circle
    radius = 20
    cx = (width - radius) - (@current_frame % (width - radius)).to_i
    cy = height / 2

    context.set_source_rgb(0.9, 0.5, 0.7) # Set the fill color to light purple
    context.circle(cx, cy, radius)
    context.fill

    # Draw a moving line
    line_length = 40
    line_start_x = (@current_frame % (width - line_length)).to_i
    line_start_y = height - 50
    line_end_x = line_start_x + line_length

    context.set_source_rgb(0.7, 0.9, 0.5) # Set the line color to light green
    context.move_to(line_start_x, line_start_y)
    context.line_to(line_end_x, line_start_y)
    context.stroke

    # Draw moving text
    text = 'Gtk3 Animation'
    text_extents = context.text_extents(text)
    text_width = text_extents.width
    text_height = text_extents.height
    text_x = (width - text_width) / 2 + (@current_frame % width)
    text_y = height - 100

    context.set_source_rgb(0.3, 0.5, 0.8)
    context.set_source_rgb(0.3, 0.5, 0.8) # Set the text color to blue # Set the text color to blue
    context.move_to(text_x, text_y)

    # Apply rotation to the context (change the rotation angle as desired)
    rotation_angle = (@current_frame % 360).to_f
    context.rotate(rotation_angle * Math::PI / 180)

    # Draw the rotated text
    context.show_text(text)
    context.stroke
  end
end

win = AnimationWindow.new
win.show_all

Gtk.main
