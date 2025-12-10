#!/usr/bin/env ruby
# prototype_card_gtk3.rb
# Prototype virtual electronic board GUI using Ruby + gtk3
# Features:
# - Push buttons
# - Toggle switches
# - LEDs (single-color with blinking)
# - 7-segment display (hex/decimal)
# - Potentiometer (slider)
# - Binary bus monitor
# - Export / import state (JSON)

require 'gtk3'
require 'json'

# Helper: LED widget using DrawingArea
class Led < Gtk::DrawingArea
  attr_accessor :on, :color, :blink_interval

  def initialize(color: :red, size: 28)
    super()
    @on = false
    @color = color
    @size = size
    set_size_request(@size, @size)
    signal_connect('draw') { |w, cr| draw_led(cr) }
    @blink_interval = nil
    @blink_id = nil
  end

  def draw_led(cr)
    alloc = allocation
    w = alloc.width
    h = alloc.height
    radius = [w,h].min / 2 - 2
    cx = w / 2.0
    cy = h / 2.0

    # background circle (off)
    cr.arc(cx, cy, radius, 0, 2*Math::PI)
    cr.set_source_rgb(0.15, 0.15, 0.15)
    cr.fill_preserve
    cr.set_source_rgb(0,0,0)
    cr.set_line_width(1)
    cr.stroke

    if @on
      r,g,b = case @color
               when :red then [1.0,0.0,0.0]
               when :green then [0.0,1.0,0.0]
               when :yellow then [1.0,1.0,0.0]
               when :blue then [0.0,0.5,1.0]
               else [1.0,0.0,0.0]
               end
      # radial gradient-ish: simple bright fill
      cr.arc(cx, cy, radius-3, 0, 2*Math::PI)
      cr.set_source_rgb(r, g, b)
      cr.fill
    end
    false
  end

  def start_blink(ms=500)
    stop_blink
    @blink_interval = ms
    @blink_id = GLib::Timeout.add(ms) do
      @on = !@on
      queue_draw
      true
    end
  end

  def stop_blink
    if @blink_id
      GLib::Source.remove(@blink_id) rescue nil
      @blink_id = nil
    end
  end
end

# Seven-segment display widget (single digit)
class SevenSeg < Gtk::DrawingArea
  SEGMENTS = {
    0 => [1,1,1,1,1,1,0],
    1 => [0,1,1,0,0,0,0],
    2 => [1,1,0,1,1,0,1],
    3 => [1,1,1,1,0,0,1],
    4 => [0,1,1,0,0,1,1],
    5 => [1,0,1,1,0,1,1],
    6 => [1,0,1,1,1,1,1],
    7 => [1,1,1,0,0,0,0],
    8 => [1,1,1,1,1,1,1],
    9 => [1,1,1,1,0,1,1],
    0xA => [1,1,1,0,1,1,1],
    0xB => [0,0,1,1,1,1,1],
    0xC => [1,0,0,1,1,1,0],
    0xD => [0,1,1,1,1,0,1],
    0xE => [1,0,0,1,1,1,1],
    0xF => [1,0,0,0,1,1,1]
  }

  def initialize(scale: 1.0)
    super()
    @value = 0
    @scale = scale
    set_size_request((40*@scale).to_i, (80*@scale).to_i)
    signal_connect('draw') { |w, cr| draw_digit(cr) }
  end

  def value=(v)
    @value = v & 0xF
    queue_draw
  end

  def draw_segment(cr, coords, lit)
    cr.move_to(*coords.first)
    coords.each { |p| cr.line_to(*p) }
    cr.close_path
    if lit
      cr.set_source_rgb(1,0.2,0.2)
      cr.fill_preserve
      cr.set_source_rgb(0.3,0,0)
      cr.set_line_width(1)
      cr.stroke
    else
      cr.set_source_rgb(0.15,0.05,0.05)
      cr.fill_preserve
      cr.set_source_rgb(0.05,0.02,0.02)
      cr.set_line_width(1)
      cr.stroke
    end
  end

  def draw_digit(cr)
    w = allocation.width
    h = allocation.height
    s = [w/40.0, h/80.0].min
    xoff = 5*s
    yoff = 5*s
    segs = SevenSeg::SEGMENTS[@value] || SevenSeg::SEGMENTS[0]

    # Precompute segment polygons (7 segments)
    # Coordinates are approximate and scaled
    a = [[10,5],[30,5],[26,9],[14,9]]
    b = [[30,5],[34,9],[34,36],[30,40],[26,36],[26,9]]
    c = [[30,44],[34,48],[34,75],[30,79],[26,75],[26,48]]
    d = [[10,75],[30,75],[26,71],[14,71]]
    e = [[6,44],[10,48],[10,75],[6,71],[2,75],[2,48]]
    f = [[6,5],[10,9],[10,36],[6,40],[2,36],[2,9]]
    g = [[10,40],[30,40],[26,44],[14,44]]

    polys = [a,b,c,d,e,f,g].map do |poly|
      poly.map { |px,py| [xoff + px*s, yoff + py*s] }
    end

    segs.each_with_index do |lit,i|
      draw_segment(cr, polys[i], lit==1)
    end
  end
end

# Small widget to display a bus as binary with LEDs
class BusDisplay < Gtk::Box
  def initialize(width)
    super(:horizontal, 6)
    @width = width
    @leds = []
    width.times do |i|
      led = Led.new(size: 18)
      pack_start(led, expand: false, fill: false, padding: 2)
      @leds << led
    end
  end

  def set_value(int)
    @width.times do |i|
      bit = (int >> ( @width - 1 - i)) & 1
      @leds[i].on = (bit==1)
      @leds[i].queue_draw
    end
  end
end

# Main application window
class BoardPrototype < Gtk::Window
  def initialize
    super
    set_title("Prototype virtuel de carte électronique")
    set_default_size(900, 500)

    signal_connect('destroy') { Gtk.main_quit }

    main = Gtk::Box.new(:horizontal, 12)
    add(main)

    # Left panel: controls
    left = Gtk::Frame.new('Contrôles')
    left.set_size_request(360, -1)
    main.pack_start(left, expand: false, fill: false, padding: 6)

    vb = Gtk::Box.new(:vertical, 8)
    vb.margin = 8
    left.add(vb)

    # Push buttons
    pb_frame = Gtk::Frame.new('Boutons poussoirs')
    pb_box = Gtk::FlowBox.new
    pb_box.max_children_per_line = 3
    %w[BTN0 BTN1 BTN2 BTN3].each do |name|
      btn = Gtk::Button.new(label: name)
      btn.set_size_request(90, 36)
      btn.signal_connect('pressed') { puts "#{name} pressed" }
      btn.signal_connect('released') { puts "#{name} released" }
      pb_box.add(btn)
    end
    pb_frame.add(pb_box)
    vb.pack_start(pb_frame, expand: false, fill: true, padding: 2)

    # Toggle switches
    sw_frame = Gtk::Frame.new('Switches (toggle)')
    sw_box = Gtk::Box.new(:horizontal, 6)
    @switches = {}
    %w[S0 S1 S2 S3].each do |s|
      tb = Gtk::ToggleButton.new(label: s)
      tb.set_size_request(72, 36)
      tb.signal_connect('toggled') { |w| puts "#{s} => #{w.active?}" }
      sw_box.pack_start(tb, expand: false, fill: false, padding: 4)
      @switches[s] = tb
    end
    sw_frame.add(sw_box)
    vb.pack_start(sw_frame, expand: false, fill: true, padding: 2)

    # Potentiometer (slider)
    pot_frame = Gtk::Frame.new('Potentiomètre')
    pot_vbox = Gtk::Box.new(:vertical,4)
    @pot = Gtk::Scale.new(:horizontal)
    @pot.adjustment = Gtk::Adjustment.new(0, 0, 1023, 1, 10, 0)
    @pot.set_value_pos(Gtk::POS_RIGHT)
    pot_vbox.pack_start(@pot, expand: false, fill: true, padding: 2)
    pot_frame.add(pot_vbox)
    vb.pack_start(pot_frame, expand: false, fill: true, padding: 2)

    # Save/Load state
    hsave = Gtk::Box.new(:horizontal, 6)
    save_btn = Gtk::Button.new(label: 'Save JSON')
    load_btn = Gtk::Button.new(label: 'Load JSON')
    hsave.pack_start(save_btn, expand: false, fill: false, padding: 2)
    hsave.pack_start(load_btn, expand: false, fill: false, padding: 2)
    vb.pack_start(hsave, expand: false, fill: false, padding: 2)

    # Right panel: indicators & displays
    right = Gtk::Box.new(:vertical, 8)
    main.pack_start(right, expand: true, fill: true, padding: 6)

    top_row = Gtk::Box.new(:horizontal, 12)
    right.pack_start(top_row, expand: false, fill: true, padding: 2)

    # LEDs group
    led_frame = Gtk::Frame.new('LEDs')
    led_box = Gtk::Box.new(:horizontal, 8)
    @led_widgets = {}
    {L0: :red, L1: :green, L2: :yellow, L3: :blue}.each do |name, color|
      l = Led.new(color: color, size: 34)
      label = Gtk::Label.new(name.to_s)
      col = Gtk::Box.new(:vertical, 2)
      col.pack_start(l, expand: false, fill: false, padding: 2)
      col.pack_start(label, expand: false, fill: false, padding: 0)
      led_box.pack_start(col, expand: false, fill: false, padding: 6)
      @led_widgets[name.to_s] = l
    end
    led_frame.add(led_box)
    top_row.pack_start(led_frame, expand: false, fill: false, padding: 6)

    # 7-segment group (4 digits)
    seg_frame = Gtk::Frame.new('Afficheur 7-seg (hex)')
    seg_box = Gtk::Box.new(:horizontal, 6)
    @segs = []
    4.times do
      s = SevenSeg.new(scale: 1.0)
      seg_box.pack_start(s, expand: false, fill: false, padding: 2)
      @segs << s
    end
    seg_frame.add(seg_box)
    top_row.pack_start(seg_frame, expand: false, fill: false, padding: 6)

    # Bus monitor
    bus_frame = Gtk::Frame.new('Bus 8 bits')
    @bus = BusDisplay.new(8)
    bus_frame.add(@bus)
    top_row.pack_start(bus_frame, expand: true, fill: false, padding: 6)

    # Bottom: logger / controls
    bottom = Gtk::Frame.new('Contrôle / Log')
    bt = Gtk::Box.new(:vertical, 6)
    bottom.add(bt)
    right.pack_start(bottom, expand: true, fill: true, padding: 2)

    # Quick set: map switches -> LEDs and bus
    wire_btn = Gtk::Button.new(label: 'Map switches -> LEDs & bus')
    wire_btn.signal_connect('clicked') { map_switches_to_leds_and_bus }
    bt.pack_start(wire_btn, expand: false, fill: false, padding: 2)

    # Simple logger view
    @logview = Gtk::TextView.new
    @logview.set_wrap_mode(:word)
    @logview.editable = false
    sc = Gtk::ScrolledWindow.new
    sc.set_policy(:automatic, :automatic)
    sc.set_min_content_height(120)
    sc.add(@logview)
    bt.pack_start(sc, expand: true, fill: true, padding: 2)

    # Save/Load actions
    save_btn.signal_connect('clicked') do
      fname = "board_state.json"
      File.write(fname, state_to_json)
      append_log("Saved state to #{fname}")
    end
    load_btn.signal_connect('clicked') do
      fname = "board_state.json"
      if File.exist?(fname)
        load_state_json(File.read(fname))
        append_log("Loaded state from #{fname}")
      else
        append_log("File #{fname} not found")
      end
    end

    # Example: connect push buttons to toggle LED L0 on press
    connect_example_behaviours

    show_all
  end

  def append_log(s)
    buf = @logview.buffer
    iter = buf.get_end_iter
    buf.insert(iter, "#{Time.now.strftime('%H:%M:%S')} - #{s}\n")
  end

  def map_switches_to_leds_and_bus
    val = 0
    @switches.keys.each_with_index do |k,i|
      active = @switches[k].active?
      @led_widgets["L#{i}"].on = active
      @led_widgets["L#{i}"].queue_draw
      val = (val << 1) | (active ? 1 : 0)
    end
    @bus.set_value(val)
    append_log("Mapped switches to LEDs and bus: #{val}")
  end

  def state_to_json
    h = {
      switches: @switches.transform_values { |w| w.active? },
      pot: @pot.value.to_i,
      leds: @led_widgets.transform_values { |led| led.on },
      segs: @segs.map { |s| s.instance_variable_get('@value') },
      bus: nil
    }
    JSON.pretty_generate(h)
  end

  def load_state_json(str)
    h = JSON.parse(str)
    h['switches'].each do |k,v|
      if @switches[k]
        @switches[k].active = v
      end
    end
    @pot.value = h['pot'] if h['pot']
    h['leds'].each do |k,v|
      if @led_widgets[k]
        @led_widgets[k].on = v
        @led_widgets[k].queue_draw
      end
    end
    if h['segs']
      h['segs'].each_with_index do |val,i|
        @segs[i].value = val.to_i
      end
    end
  end

  def connect_example_behaviours
    # Example: pressing BTN0 pulses LED L0
    # Simulate hooking hardware signals by looking up the buttons created earlier
    # The push buttons are inside the FlowBox in the left panel: we find them by label
    all_children = all_children_recursive(self)
    buttons = all_children.select { |w| w.is_a?(Gtk::Button) && w.label =~ /^BTN/ }
    btn0 = buttons.find { |b| b.label == 'BTN0' }
    if btn0
      btn0.signal_connect('pressed') do
        @led_widgets['L0'].on = true
        @led_widgets['L0'].queue_draw
        append_log('BTN0 pressed: L0 ON')
      end
      btn0.signal_connect('released') do
        @led_widgets['L0'].on = false
        @led_widgets['L0'].queue_draw
        append_log('BTN0 released: L0 OFF')
      end
    end

    # Example: pot drives the 4-digit hex display (0..0xFFFF)
    @pot.signal_connect('value-changed') do |w|
      val = w.value.to_i
      hex = val & 0xFFFF
      # split into 4 hex digits
      digits = [ (hex>>12)&0xF, (hex>>8)&0xF, (hex>>4)&0xF, (hex)&0xF ]
      @segs.each_with_index { |s,i| s.value = digits[i] }
      append_log("Pot: #{val} -> display 0x#{hex.to_s(16).upcase}")
    end
  end

  def all_children_recursive(widget)
    list = []
    if widget.respond_to?(:children)
      widget.children.each do |c|
        list << c
        list.concat(all_children_recursive(c))
      end
    elsif widget.respond_to?(:child) && widget.child
      c = widget.child
      list << c
      list.concat(all_children_recursive(c))
    end
    list
  end
end

win = BoardPrototype.new
win.show_all
Gtk.main
