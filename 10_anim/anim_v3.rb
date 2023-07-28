require 'gtk3'

class AnimationWindow < Gtk::Window
  def initialize
    super

    set_title 'Gtk3 Animation'
    signal_connect('destroy') { Gtk.main_quit }

    set_default_size(800, 600)

    # Create a vertical box to hold the drawing area and buttons
    vbox = Gtk::Box.new(:vertical, 0)

    @drawing_area = Gtk::DrawingArea.new
    @drawing_area.set_size_request(600, 400)

    vbox.pack_start(@drawing_area, expand: true, fill: true, padding: 0)

    @current_frame = 0
    @total_frames = 100
    @animation_running = false
    @animation_timer = nil
    @animation_speed = 50 # Default animation speed (50ms)
    init_animation

    @elements = [] # Store the geometric elements

    # Connect the "draw" signal to the draw_frame method
    @drawing_area.signal_connect('draw') do |widget, context|
      draw_frame(widget, context)
    end

    # Create the buttons
    start_button = Gtk::Button.new(label: 'Start')
    pause_button = Gtk::Button.new(label: 'Pause')
    exit_button = Gtk::Button.new(label: 'Exit')

    # Pack the buttons horizontally inside a Gtk::Box
    button_box = Gtk::Box.new(:horizontal, 5)
    button_box.pack_start(start_button, expand: false, fill: true, padding: 5)
    button_box.pack_start(pause_button, expand: false, fill: true, padding: 5)
    button_box.pack_start(exit_button, expand: false, fill: true, padding: 5)

    # Connect button signals
    start_button.signal_connect('clicked') { start_animation }
    pause_button.signal_connect('clicked') { pause_animation }
    exit_button.signal_connect('clicked') { Gtk.main_quit }

    # Pack the button_box at the end of the vertical box
    vbox.pack_start(button_box, expand: false, fill: true, padding: 10)

    # Create the slider for animation speed control
    @speed_slider = Gtk::Scale.new(:horizontal, 0, 100, 1)
    @speed_slider.set_value(@animation_speed)
    @speed_slider.signal_connect('value-changed') do
      @animation_speed = @speed_slider.value.to_i
      update_animation_speed
    end
    vbox.pack_start(@speed_slider, expand: false, fill: true, padding: 5)

    add(vbox)
  end

  def init_animation
    @animation_timer = GLib::Timeout.add(@animation_speed) do # Reduced timer interval (50ms = 0.05 seconds)
      if @animation_running # Check if animation is running
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
      end
      true # Keep the timer running
    end
  end

  def start_animation
    @animation_running = true
  end

  def pause_animation
    @animation_running = false
  end

  def update_animation_speed# Modify the interval of the existing timer
    # Cancel the current timer
    GLib::Source.remove(@animation_timer)
    init_animation
  end

  def draw_frame(widget, context)
    width = widget.allocated_width
    height = widget.allocated_height

    # Fill the background with light greenish-gray color
    context.set_source_rgb(0.2, 0.25, 0.2) # Set the fill color to light greenish-gray
    context.rectangle(1, 1, width - 2, height - 2) # Leave space for the border
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
          fill_color: [rand,rand,rand]
        }

        @elements << element
      end
    end

    # Draw the rectangles with random sizes and rotations
    @elements.each do |element|
      context.save do
        context.translate(element[:x] + element[:width] / 2, element[:y] + element[:height] / 2)
        context.rotate(element[:rotation] * Math::PI / 180)
        context.rectangle(-element[:width] / 2, -element[:height] / 2, element[:width], element[:height])

        # Random color for each rectangle
        context.set_source_rgb(element[:fill_color])

        context.fill
      end
    end
  end
end

win = AnimationWindow.new
win.show_all

Gtk.main
