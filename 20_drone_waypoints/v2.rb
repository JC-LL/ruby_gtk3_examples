
require 'gtk3'

class Drone
  attr_accessor :x, :y, :angle, :target_angle, :speed, :rotation_speed
  attr_reader :waypoints, :current_waypoint_index, :size, :trajectory

  def initialize(x, y, initial_angle = 0)
    @x = x
    @y = y
    @angle = initial_angle
    @target_angle = initial_angle
    @speed = 3.0
    @rotation_speed = 0.1
    @size = 20
    @waypoints = []
    @current_waypoint_index = 0
    @trajectory = []  # Nouveau: historique des positions
    @max_trajectory_points = 10000  # Limite pour éviter trop de points
  end

  def add_waypoint(x, y)
    @waypoints << [x, y]
  end

  def clear_waypoints
    @waypoints.clear
    @current_waypoint_index = 0
  end

  def clear_trajectory
    @trajectory.clear
  end

  def angle_to_target(target_x, target_y)
    dx = target_x - @x
    dy = target_y - @y
    Math.atan2(dy, dx)
  end

  def normalize_angle(angle)
    angle = angle % (2 * Math::PI)
    angle -= 2 * Math::PI if angle > Math::PI
    angle
  end

  def angle_difference(angle1, angle2)
    diff = normalize_angle(angle1 - angle2)
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
    # Enregistrer la position actuelle dans la trajectoire
    @trajectory << [@x, @y]

    # Limiter la taille de la trajectoire
    if @trajectory.length > @max_trajectory_points
      @trajectory.shift
    end

    return if @waypoints.empty?

    current_wp = @waypoints[@current_waypoint_index]
    wx, wy = current_wp

    desired_angle = angle_to_target(wx, wy)
    diff = angle_difference(desired_angle, @angle)

    if diff.abs > @rotation_speed
      @angle += (diff > 0 ? @rotation_speed : -@rotation_speed)
    else
      @angle = desired_angle
    end

    @angle = normalize_angle(@angle)

    @x += Math.cos(@angle) * @speed
    @y += Math.sin(@angle) * @speed

    if at_waypoint?(wx, wy)
      @current_waypoint_index = (@current_waypoint_index + 1) % @waypoints.length
    end
  end

  def draw(cr, width, height)
    cr.save

    # move
    cr.translate(@x, @y)
    cr.rotate(@angle)

    # Drone body
    cr.set_source_rgb(0.2, 0.6, 1.0)
    cr.move_to(@size, 0)
    cr.line_to(-@size/2, @size/2)
    cr.line_to(-@size/2, -@size/2)
    cr.close_path
    cr.fill

    cr.set_source_rgb(1, 1, 1)
    cr.arc(0, 0, 3, 0, 2 * Math::PI)
    cr.fill

    cr.set_source_rgb(1, 0, 0)
    cr.move_to(0, 0)
    cr.line_to(@size * 1.5, 0)
    cr.stroke

    cr.restore
  end

  def draw_trajectory(cr)
    return if @trajectory.length < 2

    # Dessiner la trajectoire avec un dégradé de couleur
    cr.set_line_width(2)

    @trajectory.each_with_index do |(x, y), index|
      # Plus récent = plus lumineux, plus ancien = plus foncé
      age_factor = index.to_f / @trajectory.length
      cr.set_source_rgba(0.2, 0.8, 0.2, 0.3 + 0.5 * (1.0 - age_factor))

      if index == 0
        cr.move_to(x, y)
      else
        cr.line_to(x, y)
      end
    end
    cr.stroke

    # # Points de la trajectoire (optionnel, peut être retiré si trop dense)
    # if @trajectory.length < 200  # Ne dessiner les points que si la trajectoire n'est pas trop longue
    #   @trajectory.each do |(x, y)|
    #     cr.set_source_rgba(0.2, 0.8, 0.2, 0.5)
    #     cr.arc(x, y, 2, 0, 2 * Math::PI)
    #     cr.fill
    #   end
    # end
  end

  def draw_waypoints(cr)
    # Tous les waypoints
    @waypoints.each_with_index do |(wx, wy), index|
      if index == @current_waypoint_index
        # Waypoint actif
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
      else
        # Waypoints inactifs
        cr.set_source_rgba(0.5, 0.5, 0.5, 0.7)
        cr.arc(wx, wy, 5, 0, 2 * Math::PI)
        cr.fill

        cr.set_source_rgb(0.7, 0.7, 0.7)
        cr.arc(wx, wy, 5, 0, 2 * Math::PI)
        cr.stroke
      end

      # Numéro du waypoint
      cr.set_source_rgb(1, 1, 1)
      cr.select_font_face('Sans', Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_NORMAL)
      cr.set_font_size(10)
      cr.move_to(wx + 10, wy - 10)
      cr.show_text((index + 1).to_s)
    end
  end
end

class DroneSimulation < Gtk::Window
  def initialize
    super

    set_title('Simulation de Drone 2D - Waypoints par clic avec Trajectoire')
    set_default_size(800, 600)

    @drone = Drone.new(100, 100)
    @drone.add_waypoint(400, 100)
    @drone.add_waypoint(700, 300)
    @drone.add_waypoint(400, 500)
    @drone.add_waypoint(100, 300)

    @paused = false
    @show_trajectory = true  # Nouveau: contrôle pour afficher/masquer la trajectoire

    setup_ui
    setup_timer

    signal_connect('destroy') { Gtk.main_quit }
  end

  def setup_ui
    main_box = Gtk::Box.new(:vertical, 5)
    add(main_box)

    # Zone de dessin avec événements
    @drawing_area = Gtk::DrawingArea.new
    @drawing_area.set_size_request(800, 500)
    @drawing_area.signal_connect('draw') { |widget, cr| draw(widget, cr) }

    # IMPORTANT: Activer les événements de souris
    @drawing_area.add_events(Gdk::EventMask::BUTTON_PRESS_MASK)
    @drawing_area.signal_connect('button-press-event') do |widget, event|
      handle_click(event)
      true
    end

    main_box.pack_start(@drawing_area, expand: true, fill: true, padding: 0)

    # Contrôles
    controls = Gtk::Box.new(:horizontal, 10)
    controls.margin = 10
    main_box.pack_start(controls, expand: false, fill: true, padding: 0)

    # Vitesse
    speed_label = Gtk::Label.new('Vitesse:')
    controls.pack_start(speed_label, expand: false, fill: false, padding: 0)

    @speed_scale = Gtk::Scale.new(:horizontal, 0.5, 10.0, 0.5)
    @speed_scale.value = @drone.speed
    @speed_scale.signal_connect('value-changed') do
      @drone.speed = @speed_scale.value
    end
    controls.pack_start(@speed_scale, expand: true, fill: true, padding: 0)

    # Rotation
    rotation_label = Gtk::Label.new('Rotation:')
    controls.pack_start(rotation_label, expand: false, fill: false, padding: 0)

    @rotation_scale = Gtk::Scale.new(:horizontal, 0.01, 0.3, 0.01)
    @rotation_scale.value = @drone.rotation_speed
    @rotation_scale.signal_connect('value-changed') do
      @drone.rotation_speed = @rotation_scale.value
    end
    controls.pack_start(@rotation_scale, expand: true, fill: true, padding: 0)

    # Boutons
    button_box = Gtk::ButtonBox.new(:horizontal)
    controls.pack_start(button_box, expand: false, fill: false, padding: 0)

    reset_button = Gtk::Button.new(label: 'Reset Drone')
    reset_button.signal_connect('clicked') do
      @drone.x = 100
      @drone.y = 100
      @drone.angle = 0
      @drone.clear_trajectory
      @drawing_area.queue_draw
    end
    button_box.pack_start(reset_button, expand: false, fill: false, padding: 0)

    clear_button = Gtk::Button.new(label: 'Clear Waypoints')
    clear_button.signal_connect('clicked') do
      @drone.clear_waypoints
      @drawing_area.queue_draw
    end
    button_box.pack_start(clear_button, expand: false, fill: false, padding: 0)

    # Nouveau: Bouton pour effacer la trajectoire
    clear_traj_button = Gtk::Button.new(label: 'Clear Trajectory')
    clear_traj_button.signal_connect('clicked') do
      @drone.clear_trajectory
      @drawing_area.queue_draw
    end
    button_box.pack_start(clear_traj_button, expand: false, fill: false, padding: 0)

    add_button = Gtk::Button.new(label: 'Add 4 Default Waypoints')
    add_button.signal_connect('clicked') do
      @drone.clear_waypoints
      @drone.add_waypoint(400, 100)
      @drone.add_waypoint(700, 300)
      @drone.add_waypoint(400, 500)
      @drone.add_waypoint(100, 300)
      @drawing_area.queue_draw
    end
    button_box.pack_start(add_button, expand: false, fill: false, padding: 0)

    # Nouveau: Case à cocher pour afficher/masquer la trajectoire
    @trajectory_check = Gtk::CheckButton.new('Show Trajectory')
    @trajectory_check.active = @show_trajectory
    @trajectory_check.signal_connect('toggled') do
      @show_trajectory = @trajectory_check.active?
      @drawing_area.queue_draw
    end
    button_box.pack_start(@trajectory_check, expand: false, fill: false, padding: 0)

    # Instructions
    instructions = Gtk::Label.new("CLIQUEZ GAUCHE pour ajouter un waypoint | ESPACE: pause/reprendre | T: toggle trajectoire")
    instructions.margin = 5
    main_box.pack_start(instructions, expand: false, fill: true, padding: 0)

    # Gestion clavier
    signal_connect('key-press-event') do |widget, event|
      case event.keyval
      when Gdk::Keyval::KEY_space
        @paused = !@paused
        true
      when Gdk::Keyval::KEY_t, Gdk::Keyval::KEY_T
        @show_trajectory = !@show_trajectory
        @trajectory_check.active = @show_trajectory
        @drawing_area.queue_draw
        true
      end
    end
  end

  def setup_timer
    GLib::Timeout.add(16) do
      unless @paused
        @drone.update
        @drawing_area.queue_draw
      end
      true
    end
  end

  def handle_click(event)
    if event.button == 1  # Clic gauche
      puts "Waypoint ajouté à (#{event.x.to_i}, #{event.y.to_i})"  # Debug
      @drone.add_waypoint(event.x, event.y)
      @drawing_area.queue_draw
    end
  end

  def draw(widget, cr)
    width = widget.allocated_width
    height = widget.allocated_height

    # Fond
    cr.set_source_rgb(0.05, 0.05, 0.05)  # Plus foncé pour mieux voir la trajectoire
    cr.paint

    # Grille
    cr.set_source_rgba(0.3, 0.3, 0.3, 0.3)
    cr.set_line_width(0.5)

    0.step(width, 50) do |x|
      cr.move_to(x, 0)
      cr.line_to(x, height)
      cr.stroke
    end

    0.step(height, 50) do |y|
      cr.move_to(0, y)
      cr.line_to(width, y)
      cr.stroke
    end

    # Trajectoire (dessinée avant le drone et les waypoints)
    if @show_trajectory
      @drone.draw_trajectory(cr)
    end

    # Waypoints
    @drone.draw_waypoints(cr)

    # Drone
    @drone.draw(cr, width, height)

    # Infos
    cr.set_source_rgb(1, 1, 1)
    cr.select_font_face('Sans', Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_NORMAL)
    cr.set_font_size(12)

    info = "Angle: #{'%.2f' % (@drone.angle * 180 / Math::PI)}° | " +
           "Vitesse: #{'%.1f' % @drone.speed} | " +
           "Rotation: #{'%.3f' % @drone.rotation_speed} rad/frame | " +
           "Waypoints: #{@drone.waypoints.length} | " +
           "Actuel: #{@drone.current_waypoint_index + 1} | " +
           "Trajectoire: #{@drone.trajectory.length} points"
    cr.move_to(10, 20)
    cr.show_text(info)

    # Position drone
    pos_text = "Drone: (#{@drone.x.to_i}, #{@drone.y.to_i})"
    cr.move_to(10, 40)
    cr.show_text(pos_text)

    if @paused
      cr.set_source_rgba(1, 0, 0, 0.8)
      cr.select_font_face('Sans', Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_BOLD)
      cr.set_font_size(36)
      cr.move_to(width/2 - 70, height/2)
      cr.show_text('PAUSE')
    end

    # Instructions de clic
    if @drone.waypoints.empty?
      cr.set_source_rgba(1, 1, 1, 0.7)
      cr.select_font_face('Sans', Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_NORMAL)
      cr.set_font_size(16)
      cr.move_to(width/2 - 180, height/2)
      cr.show_text('Cliquez pour ajouter votre premier waypoint')
    end
  end
end

# Lancement
app = DroneSimulation.new
app.show_all
Gtk.main
