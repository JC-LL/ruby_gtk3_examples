#!/usr/bin/env ruby

require 'gtk3'

class ElectronicPrototype
  def initialize
    # Création de la fenêtre principale
    @window = Gtk::Window.new("Prototype Électronique Virtuel")
    @window.set_default_size(800, 600)
    @window.signal_connect('destroy') { Gtk.main_quit }

    # Conteneur principal avec onglets
    create_notebook
    @window.add(@notebook)
  end

  def create_notebook
    @notebook = Gtk::Notebook.new

    # Onglet pour les entrées/sorties basiques
    create_basic_io_tab
    # Onglet pour les afficheurs
    create_display_tab
    # Onglet pour les composants avancés
    create_advanced_tab
  end

  def create_basic_io_tab
    vbox = Gtk::Box.new(:vertical, 10)
    vbox.margin = 15

    # Titre
    title = Gtk::Label.new("<b>Entrées/Sorties Basiques</b>")
    title.use_markup = true
    vbox.pack_start(title, expand: false, fill: false, padding: 5)

    # Grille pour organiser les composants
    grid = Gtk::Grid.new
    grid.row_spacing = 10
    grid.column_spacing = 15
    grid.margin_top = 20

    # Boutons poussoirs
    create_buttons_section(grid)

    # Interrupteurs (Switches)
    create_switches_section(grid)

    # LEDs
    create_leds_section(grid)

    vbox.pack_start(grid, expand: true, fill: true, padding: 0)
    @notebook.append_page(vbox, Gtk::Label.new("IO Basiques"))
  end

  def create_buttons_section(grid)
    label = Gtk::Label.new("Boutons:")
    grid.attach(label, 0, 0, 1, 1)

    @buttons = {}
    (0..3).each do |i|
      button = Gtk::Button.new(label: "BTN#{i}")
      button.signal_connect('clicked') { |btn| button_pressed(i) }
      grid.attach(button, i + 1, 0, 1, 1)
      @buttons[i] = { widget: button, state: false }
    end
  end

  def create_switches_section(grid)
    label = Gtk::Label.new("Interrupteurs:")
    grid.attach(label, 0, 1, 1, 1)

    @switches = {}
    (0..3).each do |i|
      switch_box = Gtk::Box.new(:horizontal, 5)

      switch_label = Gtk::Label.new("SW#{i}")
      switch = Gtk::Switch.new
      switch.signal_connect('state-set') { |sw, state| switch_changed(i, state) }

      state_label = Gtk::Label.new("OFF")
      state_label.name = "switch_state_#{i}"

      switch_box.pack_start(switch_label, expand: false, fill: false, padding: 0)
      switch_box.pack_start(switch, expand: false, fill: false, padding: 0)
      switch_box.pack_start(state_label, expand: false, fill: false, padding: 0)

      grid.attach(switch_box, i + 1, 1, 1, 1)
      @switches[i] = { widget: switch, state_label: state_label, state: false }
    end
  end

  def create_leds_section(grid)
    label = Gtk::Label.new("LEDs:")
    grid.attach(label, 0, 2, 1, 1)

    @leds = {}
    (0..7).each do |i|
      led_frame = Gtk::Frame.new
      led_frame.set_size_request(30, 30)
      led_frame.override_background_color(0, Gdk::RGBA.new(0.2, 0.2, 0.2, 1.0))

      led_label = Gtk::Label.new("LED#{i}")

      led_box = Gtk::Box.new(:vertical, 5)
      led_box.pack_start(led_frame, expand: false, fill: false, padding: 0)
      led_box.pack_start(led_label, expand: false, fill: false, padding: 0)

      grid.attach(led_box, i, 3, 1, 1)
      @leds[i] = { frame: led_frame, state: false }
    end
  end

  def create_display_tab
    vbox = Gtk::Box.new(:vertical, 10)
    vbox.margin = 15

    title = Gtk::Label.new("<b>Afficheurs</b>")
    title.use_markup = true
    vbox.pack_start(title, expand: false, fill: false, padding: 5)

    # Afficheur 7 segments
    create_seven_segment_display(vbox)

    # Affichage numérique
    create_numeric_display(vbox)

    @notebook.append_page(vbox, Gtk::Label.new("Afficheurs"))
  end

  def create_seven_segment_display(vbox)
    frame = Gtk::Frame.new("Afficheur 7 Segments")
    frame.margin_top = 20

    display_box = Gtk::Box.new(:vertical, 10)
    display_box.margin = 15

    # Canvas pour dessiner le 7 segments
    @segment_display = Gtk::DrawingArea.new
    @segment_display.set_size_request(200, 300)
    @segment_display.signal_connect('draw') { |widget, cr| draw_seven_segment(cr) }

    # Contrôles pour l'afficheur 7 segments
    controls_box = Gtk::Box.new(:horizontal, 10)

    (0..9).each do |digit|
      button = Gtk::Button.new(label: digit.to_s)
      button.signal_connect('clicked') { set_seven_segment_digit(digit) }
      controls_box.pack_start(button, expand: false, fill: false, padding: 0)
    end

    clear_btn = Gtk::Button.new(label: "Effacer")
    clear_btn.signal_connect('clicked') { set_seven_segment_digit(nil) }
    controls_box.pack_start(clear_btn, expand: false, fill: false, padding: 10)

    display_box.pack_start(@segment_display, expand: false, fill: false, padding: 0)
    display_box.pack_start(controls_box, expand: false, fill: false, padding: 0)

    frame.add(display_box)
    vbox.pack_start(frame, expand: false, fill: false, padding: 0)

    @current_digit = nil
  end

  def create_numeric_display(vbox)
    frame = Gtk::Frame.new("Affichage Numérique")
    frame.margin_top = 20

    display_box = Gtk::Box.new(:vertical, 10)
    display_box.margin = 15

    @numeric_display = Gtk::Label.new("0000")
    @numeric_display.name = "numeric_display"
    @numeric_display.override_font(Pango::FontDescription.new("Monospace 24"))

    spin_button = Gtk::SpinButton.new(0, 9999, 1)
    spin_button.signal_connect('value-changed') do |spinner|
      @numeric_display.text = "%04d" % spinner.value.to_i
    end

    display_box.pack_start(@numeric_display, expand: false, fill: false, padding: 0)
    display_box.pack_start(spin_button, expand: false, fill: false, padding: 10)

    frame.add(display_box)
    vbox.pack_start(frame, expand: false, fill: false, padding: 0)
  end

  def create_advanced_tab
    vbox = Gtk::Box.new(:vertical, 10)
    vbox.margin = 15

    title = Gtk::Label.new("<b>Composants Avancés</b>")
    title.use_markup = true
    vbox.pack_start(title, expand: false, fill: false, padding: 5)

    # Encodeur rotatoire simulé
    create_rotary_encoder(vbox)

    # PWM simulé
    create_pwm_control(vbox)

    @notebook.append_page(vbox, Gtk::Label.new("Avancé"))
  end

  def create_rotary_encoder(vbox)
    frame = Gtk::Frame.new("Encodeur Rotatoire")
    frame.margin_top = 20

    encoder_box = Gtk::Box.new(:vertical, 10)
    encoder_box.margin = 15

    @encoder_value = Gtk::Label.new("Position: 0")
    @encoder_value.override_font(Pango::FontDescription.new("Monospace 16"))

    button_box = Gtk::Box.new(:horizontal, 5)

    inc_btn = Gtk::Button.new(label: "+")
    inc_btn.signal_connect('clicked') { update_encoder_position(1) }

    dec_btn = Gtk::Button.new(label: "−")
    dec_btn.signal_connect('clicked') { update_encoder_position(-1) }

    reset_btn = Gtk::Button.new(label: "Reset")
    reset_btn.signal_connect('clicked') { @encoder_position = 0; update_encoder_display }

    button_box.pack_start(dec_btn, expand: false, fill: false, padding: 0)
    button_box.pack_start(inc_btn, expand: false, fill: false, padding: 0)
    button_box.pack_start(reset_btn, expand: false, fill: false, padding: 10)

    encoder_box.pack_start(@encoder_value, expand: false, fill: false, padding: 0)
    encoder_box.pack_start(button_box, expand: false, fill: false, padding: 0)

    frame.add(encoder_box)
    vbox.pack_start(frame, expand: false, fill: false, padding: 0)

    @encoder_position = 0
  end

  def create_pwm_control(vbox)
    frame = Gtk::Frame.new("Contrôle PWM")
    frame.margin_top = 20

    pwm_box = Gtk::Box.new(:vertical, 10)
    pwm_box.margin = 15

    @pwm_value = Gtk::Label.new("Rapport cyclique: 0%")

    scale = Gtk::Scale.new(:horizontal, 0, 100, 1)
    scale.value = 0
    scale.signal_connect('value-changed') do |s|
      value = s.value.to_i
      @pwm_value.text = "Rapport cyclique: #{value}%"
      update_pwm_visualization(value)
    end

    # Visualisation PWM
    @pwm_visualization = Gtk::DrawingArea.new
    @pwm_visualization.set_size_request(200, 50)
    @pwm_visualization.signal_connect('draw') { |widget, cr| draw_pwm(cr, scale.value) }

    pwm_box.pack_start(@pwm_value, expand: false, fill: false, padding: 0)
    pwm_box.pack_start(scale, expand: false, fill: false, padding: 0)
    pwm_box.pack_start(@pwm_visualization, expand: false, fill: false, padding: 10)

    frame.add(pwm_box)
    vbox.pack_start(frame, expand: false, fill: false, padding: 0)
  end

  # Méthodes de gestion des événements
  def button_pressed(index)
    puts "Bouton #{index} pressé"
    # Faire clignoter la LED correspondante
    blink_led(index)
  end

  def switch_changed(index, state)
    state_text = state ? "ON" : "OFF"
    puts "Interrupteur #{index}: #{state_text}"

    # Mettre à jour le label
    @switches[index][:state_label].text = state_text

    # Allumer/éteindre la LED correspondante
    set_led_state(index + 4, state)
  end

  def set_led_state(index, state)
    return unless @leds[index]

    @leds[index][:state] = state
    color = state ? Gdk::RGBA.new(1.0, 0.0, 0.0, 1.0) : Gdk::RGBA.new(0.2, 0.2, 0.2, 1.0)
    @leds[index][:frame].override_background_color(0, color)
  end

  def blink_led(index)
    set_led_state(index, true)
    GLib::Timeout.add(200) do
      set_led_state(index, false)
      false # Ne pas répéter le timeout
    end
  end

  def set_seven_segment_digit(digit)
    @current_digit = digit
    @segment_display.queue_draw
  end

  def draw_seven_segment(context)
    width = @segment_display.allocated_width
    height = @segment_display.allocated_height

    # Fond
    context.set_source_rgb(0.1, 0.1, 0.1)
    context.rectangle(0, 0, width, height)
    context.fill

    return unless @current_digit

    # Définition des segments pour chaque chiffre (a-g)
    segments = {
      0 => [1, 1, 1, 1, 1, 1, 0],
      1 => [0, 1, 1, 0, 0, 0, 0],
      2 => [1, 1, 0, 1, 1, 0, 1],
      3 => [1, 1, 1, 1, 0, 0, 1],
      4 => [0, 1, 1, 0, 0, 1, 1],
      5 => [1, 0, 1, 1, 0, 1, 1],
      6 => [1, 0, 1, 1, 1, 1, 1],
      7 => [1, 1, 1, 0, 0, 0, 0],
      8 => [1, 1, 1, 1, 1, 1, 1],
      9 => [1, 1, 1, 1, 0, 1, 1]
    }

    draw_segments(context, segments[@current_digit], width, height)
  end

  def draw_segments(context, segment_states, width, height)
    segment_width = width * 0.1
    segment_length = width * 0.6
    center_x = width / 2
    center_y = height / 2

    context.set_source_rgb(1.0, 0.0, 0.0) # Rouge pour les segments allumés
    context.set_line_width(segment_width)

    # Segments a-g
    segments = [
      # a (haut)
      [center_x - segment_length/2, center_y - height*0.3, center_x + segment_length/2, center_y - height*0.3],
      # b (droite haut)
      [center_x + segment_length/2, center_y - height*0.3, center_x + segment_length/2, center_y],
      # c (droite bas)
      [center_x + segment_length/2, center_y, center_x + segment_length/2, center_y + height*0.3],
      # d (bas)
      [center_x - segment_length/2, center_y + height*0.3, center_x + segment_length/2, center_y + height*0.3],
      # e (gauche bas)
      [center_x - segment_length/2, center_y, center_x - segment_length/2, center_y + height*0.3],
      # f (gauche haut)
      [center_x - segment_length/2, center_y - height*0.3, center_x - segment_length/2, center_y],
      # g (milieu)
      [center_x - segment_length/2, center_y, center_x + segment_length/2, center_y]
    ]

    segment_states.each_with_index do |state, i|
      next unless state == 1

      x1, y1, x2, y2 = segments[i]
      context.move_to(x1, y1)
      context.line_to(x2, y2)
      context.stroke
    end
  end

  def update_encoder_position(delta)
    @encoder_position += delta
    update_encoder_display
  end

  def update_encoder_display
    @encoder_value.text = "Position: #{@encoder_position}"
  end

  def draw_pwm(context, duty_cycle)
    width = @pwm_visualization.allocated_width
    height = @pwm_visualization.allocated_height

    # Fond
    context.set_source_rgb(0.1, 0.1, 0.1)
    context.rectangle(0, 0, width, height)
    context.fill

    # Signal PWM
    context.set_source_rgb(0.0, 1.0, 0.0)
    context.set_line_width(2)

    pulse_width = (width * duty_cycle / 100.0).to_i

    # Dessiner le signal carré
    context.move_to(0, height * 0.2)
    context.line_to(pulse_width, height * 0.2)
    context.line_to(pulse_width, height * 0.8)
    context.line_to(width, height * 0.8)
    context.stroke
  end

  def update_pwm_visualization(value)
    @pwm_visualization.queue_draw
  end

  def run
    @window.show_all
    Gtk.main
  end
end

# Lancement de l'application
if __FILE__ == $0
  app = ElectronicPrototype.new
  app.run
end
