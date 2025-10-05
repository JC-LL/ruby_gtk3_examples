#!/usr/bin/env ruby

require 'gtk3'
require 'cairo'

class LissajousWindow < Gtk::Window
  def initialize
    super(:toplevel)
    set_title("Générateur de Figures de Lissajous")
    set_default_size(800, 600)

    # Variables pour les paramètres
    @f1 = 3.0
    @f2 = 2.0
    @phi1 = 0.0
    @phi2 = Math::PI / 4
    @amplitude = 150.0
    @t = 0.0
    @animation_speed = 0.05

    setup_ui
    setup_animation
  end

  def setup_ui
    # Conteneur principal
    main_box = Gtk::Box.new(:vertical, 10)
    add(main_box)

    # Zone de dessin
    @drawing_area = Gtk::DrawingArea.new
    @drawing_area.set_size_request(600, 400)
    @drawing_area.signal_connect('draw') { |widget, cr| draw(widget, cr) }
    main_box.pack_start(@drawing_area, expand: true, fill: true, padding: 0)

    # Contrôles
    controls_box = Gtk::Box.new(:horizontal, 10)
    main_box.pack_start(controls_box, expand: false, fill: true, padding: 10)

    # Slider fréquence 1
    f1_box = Gtk::Box.new(:vertical, 5)
    controls_box.pack_start(f1_box, expand: true, fill: true, padding: 0)
    f1_label = Gtk::Label.new("Fréquence X: #{@f1}")
    f1_scale = Gtk::Scale.new(:horizontal, 1.0, 10.0, 0.1)
    f1_scale.value = @f1
    f1_scale.signal_connect('value-changed') do |scale|
      @f1 = scale.value
      f1_label.text = "Fréquence X: #{@f1.round(2)}"
      @drawing_area.queue_draw
    end
    f1_box.pack_start(f1_label, expand: false, fill: false, padding: 0)
    f1_box.pack_start(f1_scale, expand: true, fill: true, padding: 0)

    # Slider fréquence 2
    f2_box = Gtk::Box.new(:vertical, 5)
    controls_box.pack_start(f2_box, expand: true, fill: true, padding: 0)
    f2_label = Gtk::Label.new("Fréquence Y: #{@f2}")
    f2_scale = Gtk::Scale.new(:horizontal, 1.0, 10.0, 0.1)
    f2_scale.value = @f2
    f2_scale.signal_connect('value-changed') do |scale|
      @f2 = scale.value
      f2_label.text = "Fréquence Y: #{@f2.round(2)}"
      @drawing_area.queue_draw
    end
    f2_box.pack_start(f2_label, expand: false, fill: false, padding: 0)
    f2_box.pack_start(f2_scale, expand: true, fill: true, padding: 0)

    # Slider phase 1
    phi1_box = Gtk::Box.new(:vertical, 5)
    controls_box.pack_start(phi1_box, expand: true, fill: true, padding: 0)
    phi1_label = Gtk::Label.new("Phase X: #{@phi1.round(2)}")
    phi1_scale = Gtk::Scale.new(:horizontal, 0.0, 2 * Math::PI, 0.1)
    phi1_scale.value = @phi1
    phi1_scale.signal_connect('value-changed') do |scale|
      @phi1 = scale.value
      phi1_label.text = "Phase X: #{@phi1.round(2)}"
      @drawing_area.queue_draw
    end
    phi1_box.pack_start(phi1_label, expand: false, fill: false, padding: 0)
    phi1_box.pack_start(phi1_scale, expand: true, fill: true, padding: 0)

    # Slider phase 2
    phi2_box = Gtk::Box.new(:vertical, 5)
    controls_box.pack_start(phi2_box, expand: true, fill: true, padding: 0)
    phi2_label = Gtk::Label.new("Phase Y: #{@phi2.round(2)}")
    phi2_scale = Gtk::Scale.new(:horizontal, 0.0, 2 * Math::PI, 0.1)
    phi2_scale.value = @phi2
    phi2_scale.signal_connect('value-changed') do |scale|
      @phi2 = scale.value
      phi2_label.text = "Phase Y: #{@phi2.round(2)}"
      @drawing_area.queue_draw
    end
    phi2_box.pack_start(phi2_label, expand: false, fill: false, padding: 0)
    phi2_box.pack_start(phi2_scale, expand: true, fill: true, padding: 0)

    # Contrôles d'animation
    anim_box = Gtk::Box.new(:horizontal, 10)
    main_box.pack_start(anim_box, expand: false, fill: true, padding: 10)

    speed_label = Gtk::Label.new("Vitesse animation:")
    anim_box.pack_start(speed_label, expand: false, fill: false, padding: 0)

    speed_scale = Gtk::Scale.new(:horizontal, 0.01, 0.2, 0.01)
    speed_scale.value = @animation_speed
    speed_scale.signal_connect('value-changed') do |scale|
      @animation_speed = scale.value
    end
    anim_box.pack_start(speed_scale, expand: true, fill: true, padding: 0)

    # Bouton reset
    reset_button = Gtk::Button.new(label: "Reset Animation")
    reset_button.signal_connect('clicked') { @t = 0.0 }
    anim_box.pack_start(reset_button, expand: false, fill: false, padding: 0)
  end

  def setup_animation
    # Timer pour l'animation
    GLib::Timeout.add(16) do  # ~60 FPS
      @t += @animation_speed
      @drawing_area.queue_draw
      true  # Continue le timer
    end
  end

  def draw(widget, cr)
    width = widget.allocated_width
    height = widget.allocated_height
    center_x = width / 2
    center_y = height / 2

    # Fond
    cr.set_source_rgb(0.1, 0.1, 0.1)
    cr.paint

    # Dessiner la grille
    draw_grid(cr, width, height)

    # Calcul des points de la courbe
    points = []
    resolution = 500

    resolution.times do |i|
      theta = 2 * Math::PI * i / resolution

      # Calcul complexe : z = exp(i·(f1·θ + φ1)) + exp(i·(f2·θ + φ2))
      z1 = Complex.polar(1.0, @f1 * theta + @phi1)
      z2 = Complex.polar(1.0, @f2 * theta + @phi2)
      z = z1 + z2

      x = center_x + z.real * @amplitude
      y = center_y + z.imag * @amplitude

      points << [x, y]
    end

    # Dessiner la courbe
    cr.set_source_rgb(0.0, 0.8, 1.0)
    cr.set_line_width(2.0)

    points.each_with_index do |point, i|
      if i == 0
        cr.move_to(point[0], point[1])
      else
        cr.line_to(point[0], point[1])
      end
    end
    cr.stroke

    # Point animé (position actuelle)
    current_theta = @t % (2 * Math::PI)
    z1_current = Complex.polar(1.0, @f1 * current_theta + @phi1)
    z2_current = Complex.polar(1.0, @f2 * current_theta + @phi2)
    z_current = z1_current + z2_current

    current_x = center_x + z_current.real * @amplitude
    current_y = center_y + z_current.imag * @amplitude

    # Dessiner le point courant
    cr.set_source_rgb(1.0, 0.2, 0.2)
    cr.arc(current_x, current_y, 6, 0, 2 * Math::PI)
    cr.fill

    # Informations
    draw_info(cr, width, height)
  end

  def draw_grid(cr, width, height)
    cr.set_source_rgb(0.3, 0.3, 0.3)
    cr.set_line_width(0.5)

    # Grille verticale
    (0..width).step(50) do |x|
      cr.move_to(x, 0)
      cr.line_to(x, height)
    end

    # Grille horizontale
    (0..height).step(50) do |y|
      cr.move_to(0, y)
      cr.line_to(width, y)
    end
    cr.stroke

    # Axes centraux
    center_x = width / 2
    center_y = height / 2

    cr.set_source_rgb(0.5, 0.5, 0.5)
    cr.set_line_width(1.0)

    # Axe X
    cr.move_to(0, center_y)
    cr.line_to(width, center_y)

    # Axe Y
    cr.move_to(center_x, 0)
    cr.line_to(center_x, height)
    cr.stroke
  end

  def draw_info(cr, width, height)
    cr.set_source_rgb(0.8, 0.8, 0.8)
    cr.select_font_face("Sans", Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_NORMAL)
    cr.set_font_size(12)

    info_text = [
      "Lissajous: f₁=#{@f1.round(2)} f₂=#{@f2.round(2)} φ₁=#{@phi1.round(2)} φ₂=#{@phi2.round(2)}",
      "Rapport: #{@f1.round(2)}:#{@f2.round(2)}",
      "t = #{@t.round(2)}"
    ]

    info_text.each_with_index do |text, i|
      cr.move_to(10, 20 + i * 20)
      cr.show_text(text)
    end
  end
end

# Lancement de l'application
win = LissajousWindow.new
win.signal_connect('destroy') { Gtk.main_quit }
win.show_all

Gtk.main
