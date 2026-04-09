# robot_simulator_gtk.rb
# Simulateur de robot avec visualisation GTK3 et capteurs (odomètres, lidar)

require 'matrix'
require 'gtk3'

class Vector2D
  attr_accessor :x, :y

  def initialize(x, y)
    @x = x
    @y = y
  end

  def distance_to(other)
    Math.hypot(@x - other.x, @y - other.y)
  end

  def angle_to(other)
    Math.atan2(other.y - @y, other.x - @x)
  end

  def +(other)
    Vector2D.new(@x + other.x, @y + other.y)
  end

  def inspect
    "(#{@x.round(2)}, #{@y.round(2)})"
  end
end

class Robot
  attr_accessor :position, :orientation, :speed, :angular_speed
  attr_reader :odometer, :lidar_range, :obstacles, :trajectory

  def initialize(x: 0, y: 0, orientation: 0)
    @position = Vector2D.new(x, y)
    @orientation = orientation
    @speed = 0
    @angular_speed = 0
    @odometer = 0
    @lidar_range = 200
    @obstacles = []
    @trajectory = [Vector2D.new(x, y)]
  end

  def add_obstacle(x, y, radius)
    @obstacles << {position: Vector2D.new(x, y), radius: radius}
  end

  def update(dt)
    dx = @speed * Math.cos(@orientation) * dt
    dy = @speed * Math.sin(@orientation) * dt
    @position = @position + Vector2D.new(dx, dy)

    @orientation += @angular_speed * dt
    @orientation %= 2 * Math::PI

    @odometer += @speed * dt

    @trajectory << Vector2D.new(@position.x, @position.y)
    @trajectory = @trajectory.last(1000)
  end

  def read_odometer
    {
      total_distance: @odometer,
      position: @position,
      orientation: @orientation,
      speed: @speed,
      angular_speed: @angular_speed
    }
  end

  def read_lidar(resolution: 12, max_distance: 200)
    distances = {}
    (0...resolution).each do |i|
      angle = @orientation + (2 * Math::PI * i / resolution)
      distances[angle] = measure_distance_in_direction(angle, max_distance)
    end
    distances
  end

  def measure_distance_in_direction(direction, max_distance)
    min_distance = max_distance

    @obstacles.each do |obstacle|
      to_obstacle = Vector2D.new(
        obstacle[:position].x - @position.x,
        obstacle[:position].y - @position.y
      )

      distance_to_center = Math.hypot(to_obstacle.x, to_obstacle.y)
      angle_to_obstacle = Math.atan2(to_obstacle.y, to_obstacle.x)

      angle_diff = (direction - angle_to_obstacle).abs
      angle_diff = [angle_diff, 2 * Math::PI - angle_diff].min

      if angle_diff < Math::PI / 2
        dist = distance_to_center * Math.cos(angle_diff) - obstacle[:radius]
        if dist > 0 && dist < min_distance
          min_distance = dist
        end
      end
    end

    min_distance
  end

  def move(speed, angular_speed)
    @speed = [[speed, -50].max, 50].min
    @angular_speed = [[angular_speed, -2].max, 2].min
  end

  def stop
    @speed = 0
    @angular_speed = 0
  end

  def collision_detected?(min_distance: 10)
    front_distance = measure_distance_in_direction(@orientation, @lidar_range)
    front_distance < min_distance
  end

  def status
    {
      position: @position.inspect,
      orientation: (@orientation * 180 / Math::PI).round(1),
      speed: @speed.round(2),
      angular_speed: @angular_speed.round(2),
      odometer: @odometer.round(2)
    }
  end
end

# Comportements
module Behaviors
  class ObstacleAvoidance
    def initialize(robot, safety_distance: 30)
      @robot = robot
      @safety_distance = safety_distance
    end

    def update(dt)
      lidar_data = @robot.read_lidar(resolution: 8)
      min_distance = @robot.lidar_range
      min_angle = nil

      lidar_data.each do |angle, distance|
        if distance < min_distance
          min_distance = distance
          min_angle = angle
        end
      end

      if min_distance < @safety_distance
        angle_diff = min_angle - @robot.orientation
        turn_direction = angle_diff > 0 ? -1 : 1
        @robot.move(20, turn_direction * 1.5)
      else
        @robot.move(50, 0)
      end
    end
  end

  class WallFollowing
    def initialize(robot, wall_distance: 50, side: :right)
      @robot = robot
      @wall_distance = wall_distance
      @side = side
    end

    def update(dt)
      wall_angle = @robot.orientation + (@side == :right ? -Math::PI/2 : Math::PI/2)
      wall_distance = @robot.measure_distance_in_direction(wall_angle, 100)
      error = @wall_distance - wall_distance
      correction = [[error * 0.03, -1].max, 1].min
      @robot.move(40, correction)
    end
  end

  class RandomExploration
    def initialize(robot, change_interval: 2)
      @robot = robot
      @change_interval = change_interval
      @time_since_change = 0
      @target_speed = 30
      @target_angular = 0
    end

    def update(dt)
      @time_since_change += dt

      if @time_since_change >= @change_interval
        @target_speed = rand(20..50)
        @target_angular = rand(-1.5..1.5)
        @time_since_change = 0
      end

      if @robot.collision_detected?(min_distance: 25)
        @robot.move(-20, rand(-1..1))
      else
        @robot.move(@target_speed, @target_angular)
      end
    end
  end

  class ClearSpaceSearch
    def initialize(robot)
      @robot = robot
    end

    def update(dt)
      lidar = @robot.read_lidar(resolution: 12)
      best_direction = lidar.max_by { |angle, distance| distance }

      if best_direction && best_direction[1] > 100
        angle_diff = best_direction[0] - @robot.orientation
        angle_diff = Math.atan2(Math.sin(angle_diff), Math.cos(angle_diff))
        @robot.move(40, angle_diff * 0.5)
      else
        @robot.move(0, 1)
      end
    end
  end

  class ManualControl
    def initialize(robot)
      @robot = robot
    end

    def update(dt)
      # Contrôle manuel via l'interface
    end
  end
end

# Zone de dessin
class RobotDrawingArea < Gtk::DrawingArea
  attr_accessor :robot, :show_lidar, :show_trajectory, :zoom, :offset_x, :offset_y

  def initialize(robot)
    super()
    @robot = robot
    @show_lidar = true
    @show_trajectory = true
    @zoom = 2.0
    @offset_x = 400
    @offset_y = 300

    set_size_request(800, 600)

    add_events(Gdk::EventMask::BUTTON_PRESS_MASK |
               Gdk::EventMask::BUTTON_MOTION_MASK |
               Gdk::EventMask::SCROLL_MASK)

    # Signal moderne pour le dessin
    signal_connect(:draw) { |widget, cr| draw(widget, cr) }
  end

  def draw(widget, cr)
    # Fond
    cr.set_source_rgb(0.1, 0.1, 0.15)
    cr.paint

    # Transformation
    cr.translate(@offset_x, @offset_y)
    cr.scale(@zoom, @zoom)

    draw_grid(cr)
    draw_trajectory(cr) if @show_trajectory
    draw_obstacles(cr)
    draw_lidar(cr) if @show_lidar
    draw_robot(cr)
  end

  def draw_grid(cr)
    cr.set_source_rgba(0.3, 0.3, 0.4, 0.5)
    cr.set_line_width(0.5)

    step = 50
    (-500..500).step(step) do |x|
      cr.move_to(x, -500)
      cr.line_to(x, 500)
      cr.stroke
    end

    (-500..500).step(step) do |y|
      cr.move_to(-500, y)
      cr.line_to(500, y)
      cr.stroke
    end

    cr.set_source_rgba(0.5, 0.5, 0.6, 0.7)
    cr.set_line_width(1)
    cr.move_to(-500, 0)
    cr.line_to(500, 0)
    cr.stroke
    cr.move_to(0, -500)
    cr.line_to(0, 500)
    cr.stroke
  end

  def draw_trajectory(cr)
    cr.set_source_rgba(0.2, 0.8, 0.2, 0.6)
    cr.set_line_width(2)

    trajectory = @robot.trajectory
    return if trajectory.empty?

    cr.move_to(trajectory[0].x, -trajectory[0].y)
    trajectory.each do |point|
      cr.line_to(point.x, -point.y)
    end
    cr.stroke
  end

  def draw_obstacles(cr)
    @robot.obstacles.each do |obstacle|
      pos = obstacle[:position]
      radius = obstacle[:radius]

      cr.arc(pos.x, -pos.y, radius, 0, 2 * Math::PI)
      cr.set_source_rgba(0.8, 0.2, 0.2, 0.8)
      cr.fill_preserve
      cr.set_source_rgba(1, 0.3, 0.3, 1)
      cr.set_line_width(1)
      cr.stroke
    end
  end

  def draw_lidar(cr)
    lidar_data = @robot.read_lidar(resolution: 24)

    lidar_data.each do |angle, distance|
      if distance < @robot.lidar_range
        end_x = @robot.position.x + distance * Math.cos(angle)
        end_y = @robot.position.y + distance * Math.sin(angle)

        cr.move_to(@robot.position.x, -@robot.position.y)
        cr.line_to(end_x, -end_y)

        intensity = 1.0 - (distance / @robot.lidar_range)
        cr.set_source_rgba(0, intensity, 1 - intensity, 0.4)
        cr.set_line_width(1)
        cr.stroke
      end
    end
  end

  def draw_robot(cr)
    # Corps
    cr.arc(@robot.position.x, -@robot.position.y, 12, 0, 2 * Math::PI)
    cr.set_source_rgba(0.3, 0.6, 0.9, 0.9)
    cr.fill_preserve
    cr.set_source_rgba(0.2, 0.5, 0.8, 1)
    cr.set_line_width(2)
    cr.stroke

    # Direction
    arrow_end_x = @robot.position.x + 18 * Math.cos(@robot.orientation)
    arrow_end_y = @robot.position.y + 18 * Math.sin(@robot.orientation)

    cr.move_to(@robot.position.x, -@robot.position.y)
    cr.line_to(arrow_end_x, -arrow_end_y)
    cr.set_source_rgba(1, 0.8, 0.2, 1)
    cr.set_line_width(3)
    cr.stroke

    # Capteurs
    cr.set_source_rgba(0, 1, 0, 0.7)
    cr.arc(@robot.position.x + 10 * Math.cos(@robot.orientation + Math::PI/4),
           -(@robot.position.y + 10 * Math.sin(@robot.orientation + Math::PI/4)), 2, 0, 2 * Math::PI)
    cr.fill

    cr.arc(@robot.position.x + 10 * Math.cos(@robot.orientation - Math::PI/4),
           -(@robot.position.y + 10 * Math.sin(@robot.orientation - Math::PI/4)), 2, 0, 2 * Math::PI)
    cr.fill
  end

  def zoom_in
    @zoom *= 1.2
    @zoom = [@zoom, 10].min
    queue_draw
  end

  def zoom_out
    @zoom /= 1.2
    @zoom = [@zoom, 0.5].max
    queue_draw
  end

  def reset_view
    @zoom = 2.0
    @offset_x = 400
    @offset_y = 300
    queue_draw
  end
end

# Fenêtre principale
class RobotSimulatorWindow < Gtk::ApplicationWindow
  def initialize(application)
    super(application)
    set_title("Simulateur de Robot - GTK3")
    set_default_size(1200, 700)
    set_window_position(Gtk::WindowPosition::CENTER)

    # Création du robot
    @robot = Robot.new(x: 0, y: 0, orientation: 0)
    setup_environment

    # Zone de dessin
    @drawing_area = RobotDrawingArea.new(@robot)

    # Panneau de contrôle
    @control_panel = create_control_panel

    # Layout principal
    @main_box = Gtk::Box.new(:horizontal, 5)
    @main_box.pack_start(@drawing_area, expand: true, fill: true, padding: 5)
    @main_box.pack_start(@control_panel, expand: false, fill: false, padding: 5)
    add(@main_box)

    # Timer pour la simulation
    @last_time = Time.now
    @simulation_running = true

    GLib::Timeout.add(16) do
      if @simulation_running
        current_time = Time.now
        dt = [current_time - @last_time, 0.033].min
        @last_time = current_time

        @behavior.update(dt) if @behavior
        @robot.update(dt)

        update_info_panel
        @drawing_area.queue_draw
      end
      true
    end

    # Gestion des événements clavier
    add_events(Gdk::EventMask::KEY_PRESS_MASK)
    signal_connect(:key_press_event) do |widget, event|
      handle_key_press(event)
    end

    show_all
  end

  def setup_environment
    @robot.add_obstacle(100, 0, 20)
    @robot.add_obstacle(150, 80, 15)
    @robot.add_obstacle(-50, -50, 25)
    @robot.add_obstacle(50, 100, 18)
    @robot.add_obstacle(-30, 60, 12)
    @robot.add_obstacle(-100, -80, 22)
    @robot.add_obstacle(0, -120, 16)
    @robot.add_obstacle(120, -60, 14)
    @robot.add_obstacle(-80, 120, 20)

    @behavior = Behaviors::ObstacleAvoidance.new(@robot)
  end

  def create_control_panel
    panel = Gtk::Box.new(:vertical, 10)
    panel.set_size_request(300, -1)
    panel.set_margin_top(10)
    panel.set_margin_bottom(10)
    panel.set_margin_start(10)
    panel.set_margin_end(10)

    # Titre
    title = Gtk::Label.new
    title.set_markup("<b><big>Contrôle du Robot</big></b>")
    panel.pack_start(title, expand: false, fill: false, padding: 5)

    # Informations
    info_frame = Gtk::Frame.new("Informations")
    info_box = Gtk::Box.new(:vertical, 5)
    info_box.set_margin_top(10)
    info_box.set_margin_bottom(10)
    info_box.set_margin_start(10)
    info_box.set_margin_end(10)

    @pos_label = Gtk::Label.new("Position: (0, 0)")
    @orientation_label = Gtk::Label.new("Orientation: 0°")
    @speed_label = Gtk::Label.new("Vitesse: 0")
    @odometer_label = Gtk::Label.new("Distance: 0")

    info_box.pack_start(@pos_label, expand: false, fill: false, padding: 2)
    info_box.pack_start(@orientation_label, expand: false, fill: false, padding: 2)
    info_box.pack_start(@speed_label, expand: false, fill: false, padding: 2)
    info_box.pack_start(@odometer_label, expand: false, fill: false, padding: 2)

    info_frame.add(info_box)
    panel.pack_start(info_frame, expand: false, fill: false, padding: 5)

    # Sélection du comportement
    behavior_frame = Gtk::Frame.new("Comportement")
    behavior_box = Gtk::Box.new(:vertical, 5)
    behavior_box.set_margin_top(10)
    behavior_box.set_margin_bottom(10)
    behavior_box.set_margin_start(10)
    behavior_box.set_margin_end(10)

    @behavior_combo = Gtk::ComboBoxText.new
    @behavior_combo.append_text("Évitement d'obstacles")
    @behavior_combo.append_text("Suivi de mur (droite)")
    @behavior_combo.append_text("Exploration aléatoire")
    @behavior_combo.append_text("Recherche d'espace dégagé")
    @behavior_combo.append_text("Contrôle manuel")
    @behavior_combo.set_active(0)

    @behavior_combo.signal_connect(:changed) { change_behavior }

    behavior_box.pack_start(@behavior_combo, expand: false, fill: false, padding: 5)
    behavior_frame.add(behavior_box)
    panel.pack_start(behavior_frame, expand: false, fill: false, padding: 5)

    # Contrôles manuels
    manual_frame = Gtk::Frame.new("Contrôle Manuel")
    manual_box = Gtk::Box.new(:vertical, 5)
    manual_box.set_margin_top(10)
    manual_box.set_margin_bottom(10)
    manual_box.set_margin_start(10)
    manual_box.set_margin_end(10)

    button_grid = Gtk::Grid.new
    button_grid.set_row_homogeneous(true)
    button_grid.set_column_homogeneous(true)

    @btn_forward = Gtk::Button.new(label: "▲ Avancer")
    @btn_back = Gtk::Button.new(label: "▼ Reculer")
    @btn_left = Gtk::Button.new(label: "◄ Gauche")
    @btn_right = Gtk::Button.new(label: "► Droite")
    @btn_stop = Gtk::Button.new(label: "■ STOP")

    @btn_forward.signal_connect(:clicked) { manual_move(50, 0) }
    @btn_back.signal_connect(:clicked) { manual_move(-30, 0) }
    @btn_left.signal_connect(:clicked) { manual_move(0, -1.5) }
    @btn_right.signal_connect(:clicked) { manual_move(0, 1.5) }
    @btn_stop.signal_connect(:clicked) { @robot.stop }

    button_grid.attach(@btn_forward, 1, 0, 1, 1)
    button_grid.attach(@btn_left, 0, 1, 1, 1)
    button_grid.attach(@btn_stop, 1, 1, 1, 1)
    button_grid.attach(@btn_right, 2, 1, 1, 1)
    button_grid.attach(@btn_back, 1, 2, 1, 1)

    manual_box.pack_start(button_grid, expand: true, fill: true, padding: 5)
    manual_frame.add(manual_box)
    panel.pack_start(manual_frame, expand: true, fill: true, padding: 5)

    # Affichage
    display_frame = Gtk::Frame.new("Affichage")
    display_box = Gtk::Box.new(:vertical, 5)
    display_box.set_margin_top(10)
    display_box.set_margin_bottom(10)
    display_box.set_margin_start(10)
    display_box.set_margin_end(10)

    @check_lidar = Gtk::CheckButton.new("Afficher LiDAR")
    @check_lidar.set_active(true)
    @check_lidar.signal_connect(:toggled) do
      @drawing_area.show_lidar = @check_lidar.active?
      @drawing_area.queue_draw
    end

    @check_trajectory = Gtk::CheckButton.new("Afficher trajectoire")
    @check_trajectory.set_active(true)
    @check_trajectory.signal_connect(:toggled) do
      @drawing_area.show_trajectory = @check_trajectory.active?
      @drawing_area.queue_draw
    end

    display_box.pack_start(@check_lidar, expand: false, fill: false, padding: 2)
    display_box.pack_start(@check_trajectory, expand: false, fill: false, padding: 2)

    zoom_box = Gtk::Box.new(:horizontal, 5)
    btn_zoom_in = Gtk::Button.new(label: "+ Zoom")
    btn_zoom_out = Gtk::Button.new(label: "- Zoom")
    btn_reset_view = Gtk::Button.new(label: "Reset vue")

    btn_zoom_in.signal_connect(:clicked) { @drawing_area.zoom_in }
    btn_zoom_out.signal_connect(:clicked) { @drawing_area.zoom_out }
    btn_reset_view.signal_connect(:clicked) { @drawing_area.reset_view }

    zoom_box.pack_start(btn_zoom_in, expand: true, fill: true, padding: 2)
    zoom_box.pack_start(btn_zoom_out, expand: true, fill: true, padding: 2)
    zoom_box.pack_start(btn_reset_view, expand: true, fill: true, padding: 2)

    display_box.pack_start(zoom_box, expand: false, fill: false, padding: 5)
    display_frame.add(display_box)
    panel.pack_start(display_frame, expand: false, fill: false, padding: 5)

    # Reset
    reset_button = Gtk::Button.new(label: "🔄 Réinitialiser le robot")
    reset_button.signal_connect(:clicked) do
      @robot.position = Vector2D.new(0, 0)
      @robot.orientation = 0
      @robot.stop
      @robot.trajectory.clear
      @robot.trajectory << Vector2D.new(0, 0)
      @drawing_area.queue_draw
    end
    panel.pack_start(reset_button, expand: false, fill: false, padding: 5)

    panel
  end

  def change_behavior
    case @behavior_combo.active_text
    when "Évitement d'obstacles"
      @behavior = Behaviors::ObstacleAvoidance.new(@robot)
    when "Suivi de mur (droite)"
      @behavior = Behaviors::WallFollowing.new(@robot, side: :right)
    when "Exploration aléatoire"
      @behavior = Behaviors::RandomExploration.new(@robot)
    when "Recherche d'espace dégagé"
      @behavior = Behaviors::ClearSpaceSearch.new(@robot)
    when "Contrôle manuel"
      @behavior = Behaviors::ManualControl.new(@robot)
    end
  end

  def manual_move(speed, angular_speed)
    @robot.move(speed, angular_speed)
  end

  def update_info_panel
    status = @robot.status
    @pos_label.set_text("Position: #{status[:position]}")
    @orientation_label.set_text("Orientation: #{status[:orientation]}°")
    @speed_label.set_text("Vitesse: #{status[:speed]}")
    @odometer_label.set_text("Distance: #{status[:odometer]}")
  end

  def handle_key_press(event)
    case event.keyval
    when Gdk::Keyval::KEY_Up
      manual_move(50, 0)
    when Gdk::Keyval::KEY_Down
      manual_move(-30, 0)
    when Gdk::Keyval::KEY_Left
      manual_move(0, -1.5)
    when Gdk::Keyval::KEY_Right
      manual_move(0, 1.5)
    when Gdk::Keyval::KEY_space
      @robot.stop
    when Gdk::Keyval::KEY_r, Gdk::Keyval::KEY_R
      @robot.position = Vector2D.new(0, 0)
      @robot.orientation = 0
      @robot.stop
      @robot.trajectory.clear
      @robot.trajectory << Vector2D.new(0, 0)
      @drawing_area.queue_draw
    when Gdk::Keyval::KEY_plus, Gdk::Keyval::KEY_KP_Add
      @drawing_area.zoom_in
    when Gdk::Keyval::KEY_minus, Gdk::Keyval::KEY_KP_Subtract
      @drawing_area.zoom_out
    end
  end
end

# Application principale (méthode moderne)
class RobotSimulatorApp < Gtk::Application
  def initialize
    super('org.robot.simulator', Gio::ApplicationFlags::FLAGS_NONE)
    signal_connect(:activate) { |app| on_activate(app) }
  end

  def on_activate(app)
    window = RobotSimulatorWindow.new(app)
    window.show_all
  end
end

# Lancement
if __FILE__ == $0
  puts "=== Simulateur de Robot avec GTK3 ==="
  puts "Commandes clavier:"
  puts "  Flèches : Déplacement manuel"
  puts "  Espace : STOP"
  puts "  R : Réinitialiser position"
  puts "  +/- : Zoom"
  puts ""

  app = RobotSimulatorApp.new
  app.run
end
