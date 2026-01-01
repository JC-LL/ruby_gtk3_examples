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
    @last_button_press_time = nil

    @area = Gtk::DrawingArea.new
    setup_events
    @area.signal_connect('draw') { |widget, cr| draw(widget, cr) }

    # Permettre le focus
    @area.set_can_focus(true)
    set_can_focus(true)

    add(@area)

    # Timer pour vérifier l'état périodiquement
    GLib::Timeout.add(100) do
      check_drag_state
      true
    end

    show_all
  end

  def setup_events
    # CORRECTION: Méthode correcte pour GTK3 ruby
    # On utilise les constantes directement avec l'opérateur | bit à bit

    # Première méthode : combinaison bit à bit des constantes
    event_mask = Gdk::Event::BUTTON_PRESS_MASK |
                 Gdk::Event::BUTTON_RELEASE_MASK |
                 Gdk::Event::POINTER_MOTION_MASK |
                 Gdk::Event::SCROLL_MASK |
                 Gdk::Event::ENTER_NOTIFY_MASK |
                 Gdk::Event::LEAVE_NOTIFY_MASK

    @area.add_events(event_mask)

    # Deuxième méthode (alternative) : utiliser les symboles
    # @area.add_events(:button_press_mask, :button_release_mask, ...)

    connect_events
  end

  def connect_events
    # 1. Événements de pression de bouton
    @area.signal_connect('button_press_event') do |widget, event|
      handle_button_press(widget, event)
    end

    # 2. Événements de relâchement de bouton
    @area.signal_connect('button_release_event') do |widget, event|
      handle_button_release(widget, event)
    end

    # 3. Événements de mouvement
    @area.signal_connect('motion_notify_event') do |widget, event|
      handle_motion_notify(widget, event)
    end

    # 4. Molette
    @area.signal_connect('scroll_event') do |widget, event|
      handle_scroll(widget, event)
    end

    # 5. Entrée/sortie
    @area.signal_connect('enter_notify_event') do |widget, event|
      puts "Souris entrée dans le DrawingArea"
      true
    end

    @area.signal_connect('leave_notify_event') do |widget, event|
      puts "Souris sortie du DrawingArea"
      # Force l'arrêt du drag si on sort
      if @dragging
        puts "Drag arrêté car souris sortie de la zone"
        @dragging = false
        widget.queue_draw
      end
      true
    end

    # 6. Événements clavier (sur la fenêtre)
    signal_connect('key_press_event') do |widget, event|
      handle_key_press(widget, event)
    end

    signal_connect('key_release_event') do |widget, event|
      handle_key_release(widget, event)
    end
  end

  def handle_button_press(widget, event)
    puts "\n" + "="*60
    puts "BOUTON PRESSÉ"
    puts "Bouton: #{event.button}"
    puts "Position: (#{event.x.round(2)}, #{event.y.round(2)})"
    puts "Type: #{event.event_type}"
    puts "="*60

    # Prendre le focus quand on clique
    widget.grab_focus

    case event.button
    when 1  # Bouton gauche
      @dragging = true
      @last_button_press_time = Time.now
      @draw_path = [{x: event.x, y: event.y, time: Time.now}]
      puts "Drag COMMENCÉ"

    when 3  # Bouton droit
      @clicks.clear
      puts "Tous les clics effacés"

    when 2  # Bouton du milieu
      @draw_path.clear
      puts "Chemin de dessin effacé"
    end

    widget.queue_draw
    true
  end

  def handle_button_release(widget, event)
    puts "\n" + "="*60
    puts "BOUTON RELÂCHÉ"
    puts "Bouton: #{event.button}"
    puts "Position: (#{event.x.round(2)}, #{event.y.round(2)})"
    puts "Type: #{event.event_type}"
    puts "="*60

    if event.button == 1
      @dragging = false
      puts "Drag TERMINÉ"

      # Ajouter le point final au chemin
      if @draw_path.any?
        @draw_path << {x: event.x, y: event.y, time: Time.now}
      end
    end

    widget.queue_draw
    true
  end

  def handle_motion_notify(widget, event)
    @mouse_position = {x: event.x, y: event.y}

    # Vérifier l'état du bouton 1
    # En GTK3, on vérifie avec les flags de l'état
    button1_pressed = (event.state & Gdk::ModifierType::BUTTON1_MASK) != 0

    if @dragging
      if button1_pressed
        # Drag normal en cours
        @draw_path << {x: event.x, y: event.y, time: Time.now} if @draw_path.any?
        # Redessiner seulement occasionnellement pour performance
        widget.queue_draw if @draw_path.size % 5 == 0
      else
        # Bouton relâché mais dragging toujours vrai = BUG
        puts "ATTENTION: dragging=TRUE mais bouton 1 non pressé!"
        puts "Correction automatique..."
        @dragging = false
        widget.queue_draw
      end
    end

    true
  end

  def handle_scroll(widget, event)
    direction = event.direction

    case direction
    when :up
      puts "Molette vers le haut"
    when :down
      puts "Molette vers le bas"
    when :smooth
      puts "Défilement fluide: delta_x=#{event.delta_x}, delta_y=#{event.delta_y}"
    end

    true
  end

  def handle_key_press(widget, event)
    keyval = event.keyval
    keyname = Gdk::Keyval.to_name(keyval)

    puts "Touche pressée: #{keyname}"
    @keys_pressed[keyname] = true

    case keyname
    when "Escape"
      reset_state
      @area.queue_draw
    when "Delete"
      @clicks.pop if @clicks.any?
      @area.queue_draw
    when "d", "D"
      @dragging = !@dragging  # Toggle manuel pour debug
      puts "Drag togglé manuellement: #{@dragging}"
      @area.queue_draw
    when "r", "R"
      reset_state
      @area.queue_draw
    end

    true
  end

  def handle_key_release(widget, event)
    keyname = Gdk::Keyval.to_name(event.keyval)
    puts "Touche relâchée: #{keyname}"
    @keys_pressed.delete(keyname)
    true
  end

  def check_drag_state
    # Vérification périodique pour corriger les états invalides
    if @dragging && @last_button_press_time
      elapsed = Time.now - @last_button_press_time
      if elapsed > 10  # 10 secondes max pour un drag
        puts "Drag trop long (#{elapsed.round(1)}s), correction automatique"
        @dragging = false
        @area.queue_draw
      end
    end
  end

  def reset_state
    @dragging = false
    @clicks.clear
    @draw_path.clear
    puts "État réinitialisé"
  end

  def draw(widget, cr)
    width = widget.allocated_width
    height = widget.allocated_height

    # Fond
    draw_background(cr, width, height)

    # Grille
    draw_grid(cr, width, height)

    # Chemin de dessin
    draw_current_path(cr)

    # Clics enregistrés
    draw_recorded_clicks(cr)

    # Curseur
    draw_cursor(cr)

    # UI et informations
    draw_ui(cr, width, height)
  end

  def draw_background(cr, width, height)
    # Dégradé de fond
    pattern = Cairo::LinearPattern.new(0, 0, 0, height)
    pattern.add_color_stop_rgba(0, 0.95, 0.95, 0.95, 1)
    pattern.add_color_stop_rgba(1, 0.85, 0.85, 0.85, 1)
    cr.set_source(pattern)
    cr.paint
  end

  def draw_grid(cr, width, height)
    # Grille fine
    cr.set_source_rgba(0.7, 0.7, 0.7, 0.3)
    cr.set_line_width(0.5)

    0.step(width, 20) do |x|
      cr.move_to(x, 0)
      cr.line_to(x, height)
    end

    0.step(height, 20) do |y|
      cr.move_to(0, y)
      cr.line_to(width, y)
    end
    cr.stroke
  end

  def draw_current_path(cr)
    return if @draw_path.empty?

    # Ligne du chemin
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

    # Points de contrôle
    @draw_path.each_with_index do |point, i|
      radius = (i == 0 || i == @draw_path.length - 1) ? 6 : 4
      color = (i == 0) ? [0, 0.8, 0] : [0.8, 0.2, 0.2]

      cr.set_source_rgb(*color)
      cr.arc(point[:x], point[:y], radius, 0, 2 * Math::PI)
      cr.fill
    end
  end

  def draw_recorded_clicks(cr)
    @clicks.each_with_index do |click, i|
      # Cercle pulsant basé sur le temps
      age = Time.now - click[:time]
      pulse = (Math.sin(age * 4) + 1) / 2

      cr.set_source_rgba(1, 0.5, 0, 0.3 + pulse * 0.2)
      cr.arc(click[:x], click[:y], 25 + pulse * 5, 0, 2 * Math::PI)
      cr.fill

      cr.set_source_rgb(1, 0.7, 0)
      cr.arc(click[:x], click[:y], 15, 0, 2 * Math::PI)
      cr.fill

      # Numéro
      cr.set_source_rgb(0, 0, 0)
      cr.set_font_size(14)
      text = (i+1).to_s
      extents = cr.text_extents(text)
      cr.move_to(click[:x] - extents.width/2, click[:y] + extents.height/2)
      cr.show_text(text)
    end
  end

  def draw_cursor(cr)
    x = @mouse_position[:x]
    y = @mouse_position[:y]

    # Cercle de sélection
    radius = @dragging ? 30 : 20
    cr.set_source_rgba(0, 0, 0, 0.2)
    cr.arc(x, y, radius, 0, 2 * Math::PI)
    cr.fill

    # Réticule
    cr.set_source_rgb(0, 0, 0)
    cr.set_line_width(1)

    cross_size = @dragging ? 20 : 15
    cr.move_to(x - cross_size, y)
    cr.line_to(x + cross_size, y)
    cr.move_to(x, y - cross_size)
    cr.line_to(x, y + cross_size)
    cr.stroke

    # Point central
    if @dragging
      cr.set_source_rgb(0, 0.8, 0)
      point_radius = 4
    else
      cr.set_source_rgb(0.8, 0, 0)
      point_radius = 3
    end

    cr.arc(x, y, point_radius, 0, 2 * Math::PI)
    cr.fill
  end

  def draw_ui(cr, width, height)
    # Panneau d'information
    cr.set_source_rgba(0.1, 0.1, 0.1, 0.7)
    cr.rectangle(10, 10, 250, 100)
    cr.fill

    cr.set_source_rgb(1, 1, 1)
    cr.set_font_size(12)

    infos = [
      "Clics: #{@clicks.size}",
      "Points: #{@draw_path.size}",
      "Drag: #{@dragging ? 'OUI' : 'NON'}",
      "Souris: (#{@mouse_position[:x].round(1)}, #{@mouse_position[:y].round(1)})"
    ]

    infos.each_with_index do |info, i|
      cr.move_to(20, 40 + i * 20)
      cr.show_text(info)
    end

    # État du drag (très visible)
    if @dragging
      cr.set_source_rgba(0, 0.6, 0, 0.8)
      cr.rectangle(width/2 - 150, 50, 300, 60)
      cr.fill

      cr.set_source_rgb(1, 1, 1)
      cr.select_font_face("Sans", Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_BOLD)
      cr.set_font_size(24)

      text = "DRAGGING - RELÂCHEZ!"
      extents = cr.text_extents(text)
      cr.move_to(width/2 - extents.width/2, 50 + 40)
      cr.show_text(text)
    end

    # Instructions
    cr.set_source_rgba(0.2, 0.2, 0.5, 0.8)
    cr.rectangle(width - 260, height - 150, 250, 140)
    cr.fill

    cr.set_source_rgb(1, 1, 1)
    cr.set_font_size(11)

    instructions = [
      "INSTRUCTIONS:",
      "• Clic gauche: dessiner",
      "• Relâchez pour arrêter",
      "• Clic droit: effacer points",
      "• Clic molette: effacer dessin",
      "• ESC: tout réinitialiser",
      "• D: toggle drag (debug)"
    ]

    instructions.each_with_index do |text, i|
      cr.move_to(width - 250, height - 130 + i * 20)
      cr.show_text(text)
    end
  end
end

# Version ultra-simple de test
class SimpleDragTest < Gtk::Window
  def initialize
    super("Test Drag Simple")
    set_default_size(400, 300)

    @dragging = false
    @click_count = 0
    @positions = []

    @area = Gtk::DrawingArea.new

    # CORRECTION SIMPLE: Utiliser ALL_EVENTS_MASK
    @area.add_events(Gdk::Event::ALL_EVENTS_MASK)

    @area.signal_connect('button_press_event') do |widget, event|
      puts "PRESS event.button = #{event.button}"
      if event.button == 1
        @dragging = true
        @click_count += 1
        @positions << {x: event.x, y: event.y, type: 'press'}
        puts "Drag STARTED (click ##{@click_count})"
      end
      widget.queue_draw
      true
    end

    @area.signal_connect('button_release_event') do |widget, event|
      puts "RELEASE event.button = #{event.button}"
      if event.button == 1
        @dragging = false
        @positions << {x: event.x, y: event.y, type: 'release'}
        puts "Drag STOPPED"
      end
      widget.queue_draw
      true
    end

    @area.signal_connect('motion_notify_event') do |widget, event|
      if @dragging
        @positions << {x: event.x, y: event.y, type: 'move'}
        widget.queue_draw
      end
      true
    end

    @area.signal_connect('draw') do |widget, cr|
      draw_test(widget, cr)
    end

    add(@area)
    show_all
  end

  def draw_test(widget, cr)
    width = widget.allocated_width
    height = widget.allocated_height

    # Fond
    cr.set_source_rgb(0.9, 0.9, 0.9)
    cr.paint

    # Dessiner les positions
    @positions.each do |pos|
      if pos[:type] == 'press'
        cr.set_source_rgb(0, 0.8, 0)  # Vert pour press
        radius = 8
      elsif pos[:type] == 'release'
        cr.set_source_rgb(0.8, 0, 0)  # Rouge pour release
        radius = 8
      else
        cr.set_source_rgb(0.2, 0.2, 0.8)  # Bleu pour move
        radius = 3
      end

      cr.arc(pos[:x], pos[:y], radius, 0, 2 * Math::PI)
      cr.fill
    end

    # Texte d'état
    cr.set_source_rgb(0, 0, 0)
    cr.set_font_size(20)

    if @dragging
      cr.set_source_rgb(0, 0.6, 0)
      text = "DRAGGING - RELÂCHEZ LE BOUTON!"
    else
      cr.set_source_rgb(0.6, 0, 0)
      text = "CLIQUEZ ET TIREZ"
    end

    extents = cr.text_extents(text)
    cr.move_to(width/2 - extents.width/2, height/2)
    cr.show_text(text)

    # Informations
    cr.set_source_rgb(0.3, 0.3, 0.3)
    cr.set_font_size(12)
    cr.move_to(10, 30)
    cr.show_text("Clics: #{@click_count} | Drag: #{@dragging} | Points: #{@positions.size}")

    cr.move_to(10, height - 10)
    cr.show_text("Vert=Press, Rouge=Release, Bleu=Move")
  end
end


# Programme principal
puts "=" * 60
puts "TEST DES ÉVÉNEMENTS DRAG EN GTK3"
puts "=" * 60
puts "Choisissez le test:"
puts "1. Application complète (EventDrawingApp)"
puts "2. Test simple avec visualisation (SimpleDragTest)"
print "Votre choix (1 ou 2): "

choice = gets.chomp.to_i

case choice
when 2
  app = SimpleDragTest.new
  puts "\nLancement du test simple..."
  puts "Cliquez-glissez et regardez:"
  puts "- Points VERT: pression bouton"
  puts "- Points ROUGE: relâchement bouton"
  puts "- Points BLEU: mouvement pendant drag"
  puts "La console doit afficher PRESS et RELEASE"
else
  app = EventDrawingApp.new
end

Gtk.main
