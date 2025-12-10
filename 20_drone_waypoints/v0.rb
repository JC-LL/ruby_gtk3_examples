require 'gtk3'

class Drone
  attr_accessor :x, :y, :angle, :target_angle, :speed, :rotation_speed
  attr_reader :waypoints, :current_waypoint_index, :size

  def initialize(x, y, initial_angle = 0)
    @x = x
    @y = y
    @angle = initial_angle
    @target_angle = initial_angle
    @speed = 3.0
    @rotation_speed = 0.1  # Radians par frame
    @size = 20
    @waypoints = []
    @current_waypoint_index = 0
  end

  def add_waypoint(x, y)
    @waypoints << [x, y]
  end

  def clear_waypoints
    @waypoints.clear
    @current_waypoint_index = 0
  end

  def angle_to_target(target_x, target_y)
    dx = target_x - @x
    dy = target_y - @y
    Math.atan2(dy, dx)
  end

  def normalize_angle(angle)
    # Normalise l'angle entre -π et π
    angle = angle % (2 * Math::PI)
    angle -= 2 * Math::PI if angle > Math::PI
    angle
  end

  def angle_difference(angle1, angle2)
    diff = normalize_angle(angle1 - angle2)
    # Retourne la différence la plus courte (entre -π et π)
    if diff > Math::PI
      diff - 2 * Math::PI
    elsif diff < -Math::PI
      diff + 2 * Math::PI
    else
      diff
    end
  end

  def at_waypoint?(wx, wy, threshold = 10)
    distance = Math.sqrt((@x - wx)**2 + (@y - wy)**2)
    distance < threshold
  end

  def update
    return if @waypoints.empty?

    current_wp = @waypoints[@current_waypoint_index]
    wx, wy = current_wp

    # Calcule l'angle vers le waypoint
    desired_angle = angle_to_target(wx, wy)

    # Calcule la différence d'angle
    diff = angle_difference(desired_angle, @angle)

    # Applique la rotation progressive
    if diff.abs > @rotation_speed
      @angle += (diff > 0 ? @rotation_speed : -@rotation_speed)
    else
      @angle = desired_angle
    end

    # Normalise l'angle
    @angle = normalize_angle(@angle)

    # Avance dans la direction actuelle
    @x += Math.cos(@angle) * @speed
    @y += Math.sin(@angle) * @speed

    # Vérifie si on a atteint le waypoint
    if at_waypoint?(wx, wy)
      @current_waypoint_index = (@current_waypoint_index + 1) % @waypoints.length
    end
  end

  def draw(cr)
    # Dessine le drone (triangle orienté)
    cr.save

    # Positionne au centre du drone
    cr.translate(@x, @y)
    cr.rotate(@angle)

    # Corps du drone (triangle)
    cr.set_source_rgb(0.2, 0.6, 1.0)
    cr.move_to(@size, 0)
    cr.line_to(-@size/2, @size/2)
    cr.line_to(-@size/2, -@size/2)
    cr.close_path
    cr.fill

    # Centre du drone
    cr.set_source_rgb(1, 1, 1)
    cr.arc(0, 0, 3, 0, 2 * Math::PI)
    cr.fill

    # Direction actuelle
    cr.set_source_rgb(1, 0, 0)
    cr.move_to(0, 0)
    cr.line_to(@size * 1.5, 0)
    cr.stroke

    cr.restore

    # Dessine le waypoint cible
    if !@waypoints.empty?
      current_wp = @waypoints[@current_waypoint_index]
      wx, wy = current_wp

      cr.set_source_rgba(1, 0.5, 0, 0.7)
      cr.arc(wx, wy, 8, 0, 2 * Math::PI)
      cr.fill

      cr.set_source_rgb(1, 0.5, 0)
      cr.arc(wx, wy, 8, 0, 2 * Math::PI)
      cr.stroke

      # Ligne vers la cible
      cr.set_source_rgba(0, 1, 0, 0.3)
      cr.move_to(@x, @y)
      cr.line_to(wx, wy)
      cr.stroke
    end
  end
end

class DroneSimulation < Gtk::Window
  def initialize
    super

    set_title('Simulation de Drone 2D')
    set_default_size(800, 600)
    signal_connect('destroy') { Gtk.main_quit }

    # Crée le drone
    @drone = Drone.new(100, 100)

    # Ajoute des waypoints par défaut
    @drone.add_waypoint(400, 100)
    @drone.add_waypoint(700, 300)
    @drone.add_waypoint(400, 500)
    @drone.add_waypoint(100, 300)

    # Configuration initiale
    @speed = 3.0
    @rotation_speed = 0.1

    setup_ui
    setup_timer
  end

  def setup_ui
    # Layout principal
    main_box = Gtk::Box.new(:vertical, 5)
    add(main_box)

    # Canvas pour le dessin
    @drawing_area = Gtk::DrawingArea.new
    @drawing_area.set_size_request(800, 500)
    @drawing_area.signal_connect('draw') { |widget, cr| draw(widget, cr) }
    main_box.pack_start(@drawing_area, expand: true, fill: true, padding: 0)

    # Panneau de contrôle
    controls = Gtk::Box.new(:horizontal, 10)
    controls.margin = 10
    main_box.pack_start(controls, expand: false, fill: true, padding: 0)

    # Contrôles de vitesse
    speed_label = Gtk::Label.new('Vitesse:')
    controls.pack_start(speed_label, expand: false, fill: false, padding: 0)

    @speed_scale = Gtk::Scale.new(:horizontal, 0.5, 10.0, 0.5)
    @speed_scale.value = @speed
    @speed_scale.signal_connect('value-changed') do
      @drone.speed = @speed_scale.value
    end
    controls.pack_start(@speed_scale, expand: true, fill: true, padding: 0)

    # Contrôles de rotation
    rotation_label = Gtk::Label.new('Rotation:')
    controls.pack_start(rotation_label, expand: false, fill: false, padding: 0)

    @rotation_scale = Gtk::Scale.new(:horizontal, 0.01, 0.3, 0.01)
    @rotation_scale.value = @rotation_speed
    @rotation_scale.signal_connect('value-changed') do
      @drone.rotation_speed = @rotation_scale.value
    end
    controls.pack_start(@rotation_scale, expand: true, fill: true, padding: 0)

    # Boutons
    button_box = Gtk::ButtonBox.new(:horizontal)
    controls.pack_start(button_box, expand: false, fill: false, padding: 0)

    reset_button = Gtk::Button.new(label: 'Reset Position')
    reset_button.signal_connect('clicked') do
      @drone.x = 100
      @drone.y = 100
      @drone.angle = 0
      @drawing_area.queue_draw
    end
    button_box.pack_start(reset_button, expand: false, fill: false, padding: 0)

    clear_button = Gtk::Button.new(label: 'Clear Waypoints')
    clear_button.signal_connect('clicked') do
      @drone.clear_waypoints
      @drawing_area.queue_draw
    end
    button_box.pack_start(clear_button, expand: false, fill: false, padding: 0)

    # Instructions
    instructions = Gtk::Label.new("Cliquez pour ajouter un waypoint | Espace: pause/reprendre")
    instructions.margin = 5
    main_box.pack_start(instructions, expand: false, fill: true, padding: 0)

    # Gestion des clics
    @drawing_area.signal_connect('button-press-event') do |widget, event|
      if event.button == 1  # Clic gauche
        @drone.add_waypoint(event.x, event.y)
        widget.queue_draw
      end
    end

    # Gestion du clavier (espace pour pause)
    @paused = false
    signal_connect('key-press-event') do |widget, event|
      if event.keyval == Gdk::Keyval::GDK_KEY_space
        @paused = !@paused
      end
    end
  end

  def setup_timer
    GLib::Timeout.add(16) do  # ~60 FPS
      unless @paused
        @drone.update
        @drawing_area.queue_draw
      end
      true
    end
  end

  def draw(widget, cr)
    # Fond
    cr.set_source_rgb(0.1, 0.1, 0.1)
    cr.paint

    # Grille
    cr.set_source_rgba(0.3, 0.3, 0.3, 0.5)
    cr.set_line_width(0.5)

    0.step(widget.allocated_width, 50) do |x|
      cr.move_to(x, 0)
      cr.line_to(x, widget.allocated_height)
      cr.stroke
    end

    0.step(widget.allocated_height, 50) do |y|
      cr.move_to(0, y)
      cr.line_to(widget.allocated_width, y)
      cr.stroke
    end

    # Tous les waypoints
    cr.set_source_rgba(0.5, 0.5, 0.5, 0.5)
    @drone.waypoints.each do |wx, wy|
      cr.arc(wx, wy, 5, 0, 2 * Math::PI)
      cr.fill
    end

    # Drone
    @drone.draw(cr)

    # Informations
    cr.set_source_rgb(1, 1, 1)
    cr.select_font_face('Sans', Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_NORMAL)
    cr.set_font_size(12)

    info = "Angle: #{'%.2f' % (@drone.angle * 180 / Math::PI)}° | " +
           "Vitesse: #{'%.1f' % @drone.speed} | " +
           "Rotation: #{'%.3f' % @drone.rotation_speed} rad/frame | " +
           "Waypoint: #{@drone.current_waypoint_index + 1}/#{@drone.waypoints.length}"
    cr.move_to(10, 20)
    cr.show_text(info)

    if @paused
      cr.set_source_rgba(1, 0, 0, 0.8)
      cr.select_font_face('Sans', Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_BOLD)
      cr.set_font_size(24)
      cr.move_to(300, 250)
      cr.show_text('PAUSE')
    end
  end
end

# Lance l'application
app = DroneSimulation.new
app.show_all
Gtk.main
