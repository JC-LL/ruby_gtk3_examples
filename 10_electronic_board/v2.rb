#!/usr/bin/env ruby

require 'gtk3'

# ====================================================================
# CLASSE PERSONNALISÉE : Afficheur 7 Segments et LED (utilise DrawingArea)
# ====================================================================
class VHDLGadget < Gtk::DrawingArea
  attr_accessor :led_state, :display_value

  def initialize
    super
    @led_state = false
    @display_value = 0
    set_size_request(200, 150)

    signal_connect "draw" do |widget, cr|
      on_draw(cr)
      true
    end
  end

  def on_draw(cr)
    draw_led(cr, 20, 20)
    draw_7_segment_display(cr, 50, 5)
  end

  def draw_led(cr, x, y)
    radius = 15
    center_x = x + radius
    center_y = y + radius

    # Couleur de la LED
    cr.set_source_rgb(@led_state ? 1.0 : 0.3, 0.0, 0.0)

    cr.arc(center_x, center_y, radius, 0, 2 * Math::PI)
    cr.fill

    # Bordure
    cr.set_source_rgb(0.0, 0.0, 0.0)
    cr.set_line_width(1.0)
    cr.arc(center_x, center_y, radius, 0, 2 * Math::PI)
    cr.stroke
  end

  def draw_7_segment_display(cr, x_offset, y_offset)
    segments_map = {
      0 => [1, 1, 1, 1, 1, 1, 0], 1 => [0, 1, 1, 0, 0, 0, 0],
      2 => [1, 1, 0, 1, 1, 0, 1], 3 => [1, 1, 1, 1, 0, 0, 1],
      4 => [0, 1, 1, 0, 0, 1, 1], 5 => [1, 0, 1, 1, 0, 1, 1],
      6 => [1, 0, 1, 1, 1, 1, 1], 7 => [1, 1, 1, 0, 0, 0, 0],
      8 => [1, 1, 1, 1, 1, 1, 1], 9 => [1, 1, 1, 1, 0, 1, 1],
    }

    segments_state = segments_map[@display_value % 10] || segments_map[8]

    seg_len = 30
    seg_width = 5

    # --- PRÉ-CALCUL DES COORDONNÉES POUR ÉVITER LES AMBIGUÏTÉS ---
    # Coordonnées Y
    y_a = 5
    y_b = 10
    y_c = 15 + seg_len
    y_d = 10 + 2 * seg_len

    # Coordonnées X
    x_main = 10
    x_right = 10 + seg_len
    x_left = 10 - seg_width

    # Coordonnées des segments (Définition simple et non ambiguë)
    segment_coords = [
      # [x_start, y_start, orientation (0=H, 1=V)]
      [x_main, y_a, 0],                       # a
      [x_right, y_b, 1],                      # b
      [x_right, y_c, 1],                      # c <-- Ligne d'erreur (maintenant simplifiée)
      [x_main, y_d, 0],                       # d
      [x_left, y_c, 1],                       # e
      [x_left, y_b, 1],                       # f
      [x_main, 10 + seg_len, 0]               # g
    ]

    cr.set_line_width(seg_width)

    segment_coords.each_with_index do |(x, y, orientation), index|
      state = segments_state[index]

      # Couleur
      cr.set_source_rgb(state == 1 ? 0.0 : 0.1, state == 1 ? 1.0 : 0.2, state == 1 ? 0.0 : 0.1)

      cr.move_to(x_offset + x, y_offset + y)

      if orientation == 0 # Horizontal
        cr.line_to(x_offset + x + seg_len, y_offset + y)
      else # Vertical
        cr.line_to(x_offset + x, y_offset + y + seg_len)
      end
      cr.stroke
    end

  end

  def update_gadget
    queue_draw
  end
end

# ====================================================================
# CLASSE PRINCIPALE : Fenêtre et Logique de Contrôle
# ====================================================================
class VHDLPrototypeApp < Gtk::Window
  def initialize
    super
    set_title("VHDL Virtual Prototype (Ruby/GTK3)")
    set_default_size(400, 300)
    signal_connect("destroy") { Gtk.main_quit }

    # Initialisation primordiale
    @gadget = VHDLGadget.new

    main_box = Gtk::Box.new(:vertical, 10)
    add(main_box)

    # --- Contrôles (Entrées) ---
    control_frame = Gtk::Frame.new("Contrôles Virtuels (Entrées)")
    control_box = Gtk::Box.new(:horizontal, 10)
    control_box.set_border_width(10)
    control_frame.add(control_box)
    main_box.pack_start(control_frame, :expand => false, :fill => false, :padding => 0)

    # Bouton Poussoir
    button = Gtk::Button.new(:label => "Bouton_CLK / Compteur")
    button.signal_connect "clicked" do
      @gadget.led_state = !@gadget.led_state
      @gadget.display_value = (@gadget.display_value + 1) % 10
      @gadget.update_gadget
    end
    control_box.pack_start(button, :expand => false, :fill => false, :padding => 5)

    # Switch (Basculement/Latch)
    switch = Gtk::Switch.new
    switch.set_active(@gadget.led_state)
    switch.signal_connect "state-set" do |sw, state|
      @gadget.led_state = state
      @gadget.update_gadget
      true
    end
    switch_label = Gtk::Label.new("SW0:")
    control_box.pack_start(switch_label, :expand => false, :fill => false, :padding => 5)
    control_box.pack_start(switch, :expand => false, :fill => false, :padding => 5)


    # --- Gadgets (Sorties) ---
    gadget_frame = Gtk::Frame.new("Composants Virtuels (Sorties)")
    gadget_frame.set_border_width(10)

    gadget_frame.add(@gadget)
    main_box.pack_start(gadget_frame, :expand => true, :fill => true, :padding => 0)

    show_all
  end
end

# Lancement de l'application
VHDLPrototypeApp.new
Gtk.main
