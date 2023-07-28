require 'gtk3'
require 'pango'
require 'cairo'

class AnimationWindow < Gtk::Window
  def initialize
    super

    set_title 'Gtk3 Animation'
    signal_connect('destroy') { Gtk.main_quit }

    set_default_size(800, 600)

    @drawing_area = Gtk::DrawingArea.new
    @drawing_area.set_size_request(600, 400)
    add(@drawing_area)

    @current_frame = 0
    @total_frames = 100
    @animation_timer = nil

    init_animation

    @elements = [] # Store the geometric elements

    # Connect the "draw" signal to the draw_frame method
    @drawing_area.signal_connect('draw') do |widget, context|
      draw_frame(widget, context)
    end
  end

  def init_animation
    @animation_timer = GLib::Timeout.add(20) do # Reduced timer interval (50ms = 0.05 seconds)
      @current_frame += 1
      @current_frame %= @total_frames

      # Update elements' positions and properties (e.g., size, color) here
      @elements.each do |element|
        # Example: Update the position of a rectangle to create a bouncing effect
        element[:x] += element[:velocity_x]
        element[:y] += element[:velocity_y]

        if element[:x] <= 0 || element[:x] + element[:width] >= @drawing_area.allocated_width
          element[:velocity_x] *= -1
        end

        if element[:y] <= 0 || element[:y] + element[:height] >= @drawing_area.allocated_height
          element[:velocity_y] *= -1
        end

        # Increment rotation angle to create rotation effect
        element[:rotation] += element[:rotation_speed]
        element[:rotation] %= 360
      end

      @drawing_area.queue_draw # Request a redraw of the drawing area
      true # Keep the timer running
    end
  end

  def draw_frame(widget, context)
    width = widget.allocated_width
    height = widget.allocated_height

    context.set_source_rgb(1.0, 1.0, 1.0) # Set the fill color to white
    context.rectangle(0, 0, width, height)
    context.fill

    # Draw multiple moving rectangles with random sizes and rotations
    num_rectangles = 50

    if @elements.empty?
      # Initialize the elements only once
      num_rectangles.times do
        x = rand(0..width)
        y = rand(0..height)
        velocity_x = rand(-5..5)
        velocity_y = rand(-5..5)
        width = rand(20..50) # Random width (between 20 and 50)
        height = rand(20..50) # Random height (between 20 and 50)
        rotation_speed = rand(-5..5) # Random rotation speed (between -5 and 5 degrees per frame)

        element = {
          x: x,
          y: y,
          width: width,
          height: height,
          velocity_x: velocity_x,
          velocity_y: velocity_y,
          rotation: 0,
          rotation_speed: rotation_speed,
          rgb_fill_color: [rand, rand, rand]
        }

        @elements << element
      end
    end

    # Draw the rectangles with random sizes and rotationsRandom
    @elements.each do |element|
      context.save do
        context.translate(element[:x] + element[:width] / 2, element[:y] + element[:height] / 2)
        context.rotate(element[:rotation] * Math::PI / 180)
        context.rectangle(-element[:width] / 2, -element[:height] / 2, element[:width], element[:height])

        # color for each rectangle
        context.set_source_rgb(*element[:rgb_fill_color])

        context.fill
      end
    end
  end
end



win = AnimationWindow.new
win.show_all

Gtk.main
