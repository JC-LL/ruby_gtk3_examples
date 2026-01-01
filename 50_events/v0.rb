require 'gtk3'

class EventDrawingApp < Gtk::Window
  def initialize
    super("Événements GTK3 + Dessin Cairo")
    set_default_size(600, 400)

    @clicks = []
    @mouse_position = {x: 0, y: 0}
    @dragging = false
    @draw_path = []
    @keys_pressed = {}

    @area = Gtk::DrawingArea.new
    setup_events
    @area.signal_connect('draw') { |widget, cr| draw(widget, cr) }

    # Pour recevoir les événements clavier, la fenêtre doit pouvoir avoir le focus
    set_can_focus(true)  # CORRECTION: utiliser set_can_focus au lieu de set_focusable

    add(@area)
    show_all
  end

  def setup_events
    # Déclarer tous les événements qu'on veut recevoir
    @area.add_events(:all_events_mask)

    # Connecter chaque type d'événement
    connect_mouse_events
    connect_keyboard_events
    connect_window_events
  end

  def connect_mouse_events
    # Clic souris
    @area.signal_connect('button_press_event') do |widget, event|
      puts "Clic bouton #{event.button} à (#{event.x.round(1)}, #{event.y.round(1)})"

      case event.button
      when 1  # Clic gauche
        @clicks << {x: event.x, y: event.y, time: Time.now}
        @dragging = true
        @draw_path = [{x: event.x, y: event.y}]

      when 3  # Clic droit
        @clicks.clear

      when 2  # Clic molette
        @draw_path.clear
      end

      widget.queue_draw  # Force le redessin
      true  # Événement traité
    end

    # Relâchement souris
    @area.signal_connect('button_release_event') do |widget, event|
      puts "Relâchement bouton #{event.button}"
      @dragging = false if event.button == 1
      true
    end

    # Mouvement souris
    @area.signal_connect('motion_notify_event') do |widget, event|
      @mouse_position = {x: event.x, y: event.y}

      if @dragging
        @draw_path << {x: event.x, y: event.y}
        widget.queue_draw  # Redessine en temps réel!
      end

      true
    end

    # Molette
    @area.signal_connect('scroll_event') do |widget, event|
      direction = event.direction
      delta_x = event.delta_x
      delta_y = event.delta_y

      puts "Molette: direction=#{direction}, delta=(#{delta_x}, #{delta_y})"

      if direction == :smooth
        puts "Défilement fluide (trackpad)"
      end

      true
    end

    # Entrée/sortie de la zone
    @area.signal_connect('enter_notify_event') do |widget, event|
      puts "Souris entrée dans la zone"
      true
    end

    @area.signal_connect('leave_notify_event') do |widget, event|
      puts "Souris sortie de la zone"
      @dragging = false
      true
    end
  end

  def connect_keyboard_events
    # CORRECTION: La fenêtre reçoit déjà les événements clavier
    # quand elle a le focus. On connecte directement sur la fenêtre.

    # Événements clavier sur la fenêtre
    signal_connect('key_press_event') do |widget, event|
      keyval = event.keyval
      keyname = Gdk::Keyval.to_name(keyval)
      state = event.state

      puts "Touche pressée: #{keyname} (keyval: #{keyval})"
      @keys_pressed[keyname] = true

      # Modifieurs (Shift, Ctrl, Alt)
      modifiers = []
      modifiers << "Ctrl" if state.control_mask?
      modifiers << "Shift" if state.shift_mask?
      modifiers << "Alt" if state.mod1_mask?
      puts "Modifieurs: #{modifiers.join('+')}" unless modifiers.empty?

      # Actions spécifiques
      case keyname
      when "Escape"
        @clicks.clear
        @draw_path.clear
        @area.queue_draw
      when "c", "C"
        puts "Touche C pressée"
      when "Delete"
        @clicks.pop if @clicks.any?
        @area.queue_draw
      when "plus", "equal"  # + (peut être = sur certains claviers)
        puts "Zoom in"
      when "minus"
        puts "Zoom out"
      end

      true  # Événement traité
    end

    signal_connect('key_release_event') do |widget, event|
      keyname = Gdk::Keyval.to_name(event.keyval)
      puts "Touche relâchée: #{keyname}"
      @keys_pressed.delete(keyname)
      true
    end

    # Pour que le DrawingArea puisse aussi recevoir le focus clavier
    @area.set_can_focus(true)  # CORRECTION: Permettre au DrawingArea d'avoir le focus

    @area.signal_connect('key_press_event') do |widget, event|
      puts "Touche pressée dans le DrawingArea: #{Gdk::Keyval.to_name(event.keyval)}"
      true
    end
  end

  def connect_window_events
    # Redimensionnement
    signal_connect('configure-event') do |widget, event|
      puts "Fenêtre redimensionnée: #{event.width}x#{event.height}"
      true
    end

    # Fermeture
    signal_connect('destroy') do |widget|
      puts "Fenêtre en cours de destruction"
      Gtk.main_quit
    end

    # Focus
    signal_connect('focus_in_event') do |widget, event|
      puts "Fenêtre a reçu le focus"
      true
    end

    signal_connect('focus_out_event') do |widget, event|
      puts "Fenêtre a perdu le focus"
      true
    end

    # Événement show pour s'assurer que la fenêtre est prête
    signal_connect('show') do |widget|
      puts "Fenêtre affichée"
      # Donner le focus à la fenêtre
      widget.grab_focus
    end
  end

  def draw(widget, cr)
    width = widget.allocated_width
    height = widget.allocated_height

    # Fond
    cr.set_source_rgb(0.95, 0.95, 0.95)
    cr.paint

    # Grille de référence
    draw_grid(cr, width, height)

    # 1. Dessiner le chemin en cours (si on drag)
    if @draw_path.any?
      cr.set_source_rgb(0.2, 0.4, 0.8)
      cr.set_line_width(3)
      cr.set_line_cap(Cairo::LINE_CAP_ROUND)
      cr.set_line_join(Cairo::LINE_JOIN_ROUND)

      @draw_path.each_with_index do |point, i|
        if i == 0
          cr.move_to(point[:x], point[:y])
        else
          cr.line_to(point[:x], point[:y])
        end
      end
      cr.stroke
    end

    # 2. Dessiner les clics enregistrés
    @clicks.each_with_index do |click, i|
      age = Time.now - click[:time]
      alpha = [1.0 - age/10.0, 0.1].max  # Disparaît en 10 secondes

      # Cercle avec dégradé de couleur selon l'âge
      cr.set_source_rgba(1, 0.5 - alpha/2, 0, alpha)
      cr.arc(click[:x], click[:y], 20 * alpha, 0, 2 * Math::PI)
      cr.fill

      # Numéro
      cr.set_source_rgb(0, 0, 0)
      cr.set_font_size(12)
      text = (i+1).to_s
      extents = cr.text_extents(text)
      cr.move_to(click[:x] - extents.width/2, click[:y] + extents.height/2)
      cr.show_text(text)
    end

    # 3. Curseur de souris
    draw_cursor(cr, @mouse_position[:x], @mouse_position[:y])

    # 4. Touches pressées (affichage)
    draw_keys_info(cr, width, height)

    # 5. Informations
    draw_info(cr, width, height)
  end

  def draw_grid(cr, width, height)
    cr.set_source_rgba(0.8, 0.8, 0.8, 0.5)
    cr.set_line_width(1)

    # Lignes verticales
    (0..width).step(50) do |x|
      cr.move_to(x, 0)
      cr.line_to(x, height)
    end

    # Lignes horizontales
    (0..height).step(50) do |y|
      cr.move_to(0, y)
      cr.line_to(width, y)
    end
    cr.stroke

    # Axes centraux
    cr.set_source_rgba(0, 0, 0.8, 0.3)
    cr.set_line_width(2)
    cr.move_to(width/2, 0)
    cr.line_to(width/2, height)
    cr.move_to(0, height/2)
    cr.line_to(width, height/2)
    cr.stroke
  end

  def draw_cursor(cr, x, y)
    # Réticule
    cr.set_source_rgb(0, 0, 0)
    cr.set_line_width(1)

    # Croix
    cr.move_to(x - 15, y)
    cr.line_to(x + 15, y)
    cr.move_to(x, y - 15)
    cr.line_to(x, y + 15)
    cr.stroke

    # Cercle
    cr.arc(x, y, 20, 0, 2 * Math::PI)
    cr.set_dash([5, 5], 0)
    cr.stroke
    cr.set_dash([], 0)

    # Point central
    cr.set_source_rgb(1, 0, 0)
    cr.arc(x, y, 3, 0, 2 * Math::PI)
    cr.fill
  end

  def draw_keys_info(cr, width, height)
    # Afficher les touches actuellement pressées
    if @keys_pressed.any?
      cr.set_source_rgba(0.2, 0.6, 0.2, 0.7)
      cr.rectangle(width - 150, 10, 140, 30 + @keys_pressed.size * 20)
      cr.fill

      cr.set_source_rgb(1, 1, 1)
      cr.set_font_size(12)
      cr.move_to(width - 140, 30)
      cr.show_text("Touches pressées:")

      @keys_pressed.keys.each_with_index do |key, i|
        cr.move_to(width - 140, 55 + i * 20)
        cr.show_text("• #{key}")
      end
    end
  end

  def draw_info(cr, width, height)
    cr.set_source_rgb(0, 0, 0)
    cr.set_font_size(12)

    infos = [
      "Clics: #{@clicks.size}",
      "Points dans le chemin: #{@draw_path.size}",
      "Drag: #{@dragging ? 'OUI' : 'NON'}",
      "Souris: (#{@mouse_position[:x].round(1)}, #{@mouse_position[:y].round(1)})",
      "Taille: #{width}x#{height}"
    ]

    infos.each_with_index do |info, i|
      cr.move_to(10, 30 + i * 20)
      cr.show_text(info)
    end

    # Instructions
    instructions = [
      "Clic gauche: ajoute un point / commence à dessiner",
      "Clic droit: efface tous les points",
      "Clic molette: efface le dessin",
      "ESC: tout effacer",
      "Delete: supprime le dernier point",
      "+/-: zoom (à tester)",
      "Touches: voir en haut à droite"
    ]

    cr.set_source_rgb(0.3, 0.3, 0.3)
    cr.set_font_size(10)
    instructions.each_with_index do |text, i|
      cr.move_to(10, height - 150 + i * 15)
      cr.show_text(text)
    end
  end
end

# Lancer l'application
app = EventDrawingApp.new
Gtk.main
