require 'gtk3'

class Vec2D
  attr_accessor :x, :y

  def initialize(x = 0, y = 0)
    @x = x
    @y = y
  end

  def +(other)
    Vec2D.new(@x + other.x, @y + other.y)
  end

  def -(other)
    Vec2D.new(@x - other.x, @y - other.y)
  end

  def *(scalar)
    Vec2D.new(@x * scalar, @y * scalar)
  end

  def /(scalar)
    Vec2D.new(@x / scalar.to_f, @y / scalar.to_f)
  end

  def magnitude
    Math.sqrt(@x * @x + @y * @y)
  end

  def normalize
    mag = magnitude
    mag > 0 ? self / mag : Vec2D.new
  end

  def limit(max)
    mag = magnitude
    mag > max ? self.normalize * max : self
  end

  def distance(other)
    Math.sqrt((@x - other.x) ** 2 + (@y - other.y) ** 2)
  end
end

class Boid
  attr_accessor :position, :velocity, :acceleration

  def initialize(width, height)
    @position = Vec2D.new(rand(width), rand(height))
    @velocity = Vec2D.new(rand(-1.0..1.0), rand(-1.0..1.0))
    @acceleration = Vec2D.new
    @max_speed = 5.0  # Augmenté pour plus de réactivité
    @max_force = 0.3  # Augmenté pour plus de réactivité
    @perception = 60  # Augmenté pour voir plus loin
  end

  def apply_force(force)
    @acceleration += force
  end

  def flock(boids, mouse_position)
    alignment = align(boids)
    cohesion = cohere(boids)
    separation = separate(boids)
    seek_mouse = seek(mouse_position)

    # Ajustement des poids pour plus de réactivité
    alignment *= 1.2    # Augmenté
    cohesion *= 1.2     # Augmenté
    separation *= 1.8   # Augmenté
    seek_mouse *= 1.5   # Augmenté pour suivre la souris plus fortement

    apply_force(alignment)
    apply_force(cohesion)
    apply_force(separation)
    apply_force(seek_mouse)
  end

  def align(boids)
    steering = Vec2D.new
    total = 0

    boids.each do |other|
      d = @position.distance(other.position)
      if d > 0 && d < @perception
        steering += other.velocity
        total += 1
      end
    end

    if total > 0
      steering /= total
      steering = steering.normalize * @max_speed
      steering -= @velocity
      steering = steering.limit(@max_force)
    end

    steering
  end

  def cohere(boids)
    steering = Vec2D.new
    total = 0

    boids.each do |other|
      d = @position.distance(other.position)
      if d > 0 && d < @perception
        steering += other.position
        total += 1
      end
    end

    if total > 0
      steering /= total
      steering -= @position
      steering = steering.normalize * @max_speed
      steering -= @velocity
      steering = steering.limit(@max_force)
    end

    steering
  end

  def separate(boids)
    steering = Vec2D.new
    total = 0

    boids.each do |other|
      d = @position.distance(other.position)
      if d > 0 && d < @perception * 0.6  # Zone de séparation plus grande
        diff = @position - other.position
        diff /= d * d  # Plus c'est proche, plus c'est fort
        steering += diff
        total += 1
      end
    end

    if total > 0
      steering /= total
      steering = steering.normalize * @max_speed
      steering -= @velocity
      steering = steering.limit(@max_force * 1.5)  # Force de séparation augmentée
    end

    steering
  end

  def seek(target)
    desired = target - @position
    distance = desired.magnitude

    # Plus la souris est proche, plus l'attraction est forte
    if distance > 0
      # Ralentir quand on s'approche de la cible
      speed = distance < 100 ? @max_speed * (distance / 100.0) : @max_speed
      desired = desired.normalize * speed

      steering = desired - @velocity
      steering = steering.limit(@max_force)
      return steering
    end

    Vec2D.new
  end

  def update(width, height)
    @velocity += @acceleration
    @velocity = @velocity.limit(@max_speed)
    @position += @velocity
    @acceleration *= 0

    # Rebond sur les bords
    if @position.x < 0
      @position.x = width
    elsif @position.x > width
      @position.x = 0
    end

    if @position.y < 0
      @position.y = height
    elsif @position.y > height
      @position.y = 0
    end
  end

  def draw(cr)
    # Dessiner un triangle orienté dans la direction du mouvement
    angle = Math.atan2(@velocity.y, @velocity.x)

    cr.save do
      cr.translate(@position.x, @position.y)
      cr.rotate(angle)

      # Couleur en fonction de la vitesse
      speed = @velocity.magnitude / @max_speed
      r = 0.7
      g = 0.2 + speed * 0.3
      b = 0.2

      cr.set_source_rgb(r, g, b)
      cr.move_to(12, 0)  # Triangle légèrement plus grand
      cr.line_to(-8, -6)
      cr.line_to(-8, 6)
      cr.close_path
      cr.fill

      # Petit cercle au centre
      cr.set_source_rgb(1, 1, 1)
      cr.arc(0, 0, 2, 0, 2 * Math::PI)
      cr.fill
    end
  end
end

class BoidsWindow < Gtk::Window
  def initialize
    super

    set_title('Simulation de Boïds - Suivi de souris')
    set_default_size(1200, 800)
    signal_connect('destroy') { Gtk.main_quit }

    # Configuration initiale
    @width = 1200
    @height = 800
    @boids = Array.new(80) { Boid.new(@width, @height) }  # Plus de boids
    @mouse_position = Vec2D.new(@width / 2, @height / 2)
    @last_update_time = Time.now
    @fps = 0
    @frame_count = 0
    @fps_time = Time.now

    # Créer un conteneur principal
    @main_box = Gtk::Box.new(:vertical, 0)
    add(@main_box)

    # Créer une zone de dessin avec expansion
    @drawing_area = Gtk::DrawingArea.new
    @drawing_area.set_hexpand(true)
    @drawing_area.set_vexpand(true)
    @drawing_area.signal_connect('draw') { |widget, cr| draw(widget, cr) }

    # Gérer le redimensionnement
    @drawing_area.signal_connect('configure-event') do |widget, event|
      allocation = widget.allocation
      @width = allocation.width
      @height = allocation.height
      false
    end

    # Ajouter un panneau de contrôle
    @controls_box = Gtk::Box.new(:horizontal, 10)
    @controls_box.margin = 10

    # Label d'information
    @info_label = Gtk::Label.new
    @info_label.set_markup("<span foreground='white'>80 boïds actifs - Déplacez la souris pour les attirer</span>")
    @controls_box.pack_start(@info_label, expand: false, fill: false, padding: 0)

    # Bouton pour ajouter des boïds
    @add_button = Gtk::Button.new(label: "+10 boïds")
    @add_button.signal_connect('clicked') do
      10.times { @boids << Boid.new(@width, @height) }
      update_info
    end
    @controls_box.pack_start(@add_button, expand: false, fill: false, padding: 0)

    # Bouton pour retirer des boïds
    @remove_button = Gtk::Button.new(label: "-10 boïds")
    @remove_button.signal_connect('clicked') do
      @boids.pop(10) if @boids.size > 10
      update_info
    end
    @controls_box.pack_start(@remove_button, expand: false, fill: false, padding: 0)

    # Ajouter un fond sombre au panneau de contrôle
    @controls_style = Gtk::CssProvider.new
    @controls_style.load(data: <<-CSS)
      box {
        background-color: #2a2a3a;
        border-radius: 5px;
        padding: 10px;
      }
    CSS

    @controls_box.style_context.add_provider(@controls_style, Gtk::StyleProvider::PRIORITY_USER)

    @main_box.pack_start(@drawing_area, expand: true, fill: true, padding: 0)
    @main_box.pack_start(@controls_box, expand: false, fill: true, padding: 0)

    # Suivi de la souris - CORRECTION ICI
    @drawing_area.add_events(Gdk::EventMask::POINTER_MOTION_MASK |
                           Gdk::EventMask::BUTTON_PRESS_MASK)

    @drawing_area.signal_connect('motion-notify-event') do |widget, event|
      @mouse_position = Vec2D.new(event.x, event.y)
      queue_draw
    end

    @drawing_area.signal_connect('button-press-event') do |widget, event|
      @mouse_position = Vec2D.new(event.x, event.y)
      queue_draw
    end

    # Animation avec timing précis
    GLib::Timeout.add(16) do # ~60 FPS
      update
      true
    end

    show_all
  end

  def update_info
    @info_label.set_markup("<span foreground='white'>#{@boids.size} boïds actifs - Déplacez la souris pour les attirer</span>")
  end

  def update
    current_time = Time.now
    delta_time = current_time - @last_update_time
    @last_update_time = current_time

    # Mettre à jour tous les boids
    @boids.each do |boid|
      boid.flock(@boids, @mouse_position)
      boid.update(@width, @height)
    end

    # Calculer les FPS
    @frame_count += 1
    if current_time - @fps_time >= 1.0
      @fps = @frame_count
      @frame_count = 0
      @fps_time = current_time
    end

    queue_draw
  end

  def draw(widget, cr)
    # Fond avec dégradé
    pattern = Cairo::LinearPattern.new(0, 0, 0, @height)
    pattern.add_color_stop_rgb(0, 0.05, 0.05, 0.1)
    pattern.add_color_stop_rgb(1, 0.1, 0.1, 0.2)
    cr.set_source(pattern)
    cr.paint

    # Dessiner tous les boids
    @boids.each do |boid|
      boid.draw(cr)
    end

    # Dessiner le curseur avec effet visuel
    cr.set_source_rgba(0.2, 0.5, 1.0, 0.2)
    cr.arc(@mouse_position.x, @mouse_position.y, 30, 0, 2 * Math::PI)
    cr.fill

    cr.set_source_rgba(0.2, 0.6, 1.0, 0.4)
    cr.arc(@mouse_position.x, @mouse_position.y, 15, 0, 2 * Math::PI)
    cr.fill

    cr.set_source_rgb(0.2, 0.8, 1.0)
    cr.arc(@mouse_position.x, @mouse_position.y, 5, 0, 2 * Math::PI)
    cr.fill

    # Informations
    cr.set_source_rgb(1, 1, 1)
    cr.select_font_face("Sans", Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_NORMAL)
    cr.set_font_size(14)

    cr.move_to(20, 30)
    cr.show_text("Boïds: #{@boids.size}")

    cr.move_to(20, 55)
    cr.show_text("FPS: #{@fps}")

    cr.move_to(20, 80)
    cr.show_text("Position souris: #{@mouse_position.x.to_i}, #{@mouse_position.y.to_i}")

    # Instructions
    cr.set_font_size(12)
    cr.move_to(@width - 300, 30)
    cr.show_text("Utilisez les boutons pour ajuster le nombre de boïds")

    cr.move_to(@width - 300, 55)
    cr.show_text("Les boïds suivent activement le pointeur de la souris")
  end
end

# Démarrer l'application
app = BoidsWindow.new
Gtk.main
