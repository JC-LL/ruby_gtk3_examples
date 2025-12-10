require 'gtk3'
require 'cairo'

class DrawingAreaTutorial < Gtk::Window
  def initialize
    super(:toplevel)
    set_title("Tutorial Drawing Area GTK3/Ruby")
    set_default_size(800, 600)

    # Création de la Drawing Area
    @drawing_area = Gtk::DrawingArea.new

    # CONCEPT CLÉ 1: Connecter le signal 'draw'
    @drawing_area.signal_connect('draw') do |widget, cr|
      on_draw(widget, cr)
    end

    # CONCEPT CLÉ 2: Gérer les événements de souris
    @drawing_area.signal_connect('button-press-event') do |widget, event|
      on_button_press(widget, event)
    end

    @drawing_area.signal_connect('motion-notify-event') do |widget, event|
      on_mouse_move(widget, event)
    end

    # Activer les événements de souris
    @drawing_area.add_events(Gdk::EventMask::BUTTON_PRESS_MASK |
                            Gdk::EventMask::POINTER_MOTION_MASK)

    # Variables pour l'interactivité
    @mouse_x = 0
    @mouse_y = 0
    @click_points = []
    @animation_angle = 0

    # CONCEPT CLÉ 3: Animation avec timeout
    GLib::Timeout.add(16) do # ≈ 60 FPS
      @animation_angle += 0.05
      @drawing_area.queue_draw  # Force le redessin
      true # Continue le timer
    end

    # Layout
    add(@drawing_area)
    show_all
  end

  def on_draw(widget, cr)
    width = widget.allocated_width
    height = widget.allocated_height

    # CONCEPT CLÉ 4: Effacer l'arrière-plan
    cr.set_source_rgb(0.95, 0.95, 0.95) # Gris clair
    cr.paint

    draw_basic_shapes(cr, width, height)
    draw_text_examples(cr, width, height)
    draw_interactive_elements(cr, width, height)
    draw_animation(cr, width, height)
  end

  def draw_basic_shapes(cr, width, height)
    # CONCEPT CLÉ 5: Formes géométriques de base

    # Rectangle rempli
    cr.set_source_rgb(0.8, 0.2, 0.2) # Rouge
    cr.rectangle(50, 50, 100, 80)
    cr.fill

    # Rectangle avec bordure
    cr.set_source_rgb(0.2, 0.2, 0.8) # Bleu
    cr.rectangle(50, 150, 100, 80)
    cr.set_line_width(3)
    cr.stroke

    # Cercle
    cr.set_source_rgb(0.2, 0.8, 0.2) # Vert
    cr.arc(200, 100, 40, 0, 2 * Math::PI)
    cr.fill

    # Ligne
    cr.set_source_rgb(0, 0, 0)
    cr.set_line_width(2)
    cr.move_to(300, 50)
    cr.line_to(400, 150)
    cr.stroke

    # Ligne pointillée
    cr.set_dash([5.0, 3.0])
    cr.move_to(300, 100)
    cr.line_to(400, 200)
    cr.stroke
    cr.set_dash([]) # Réinitialiser

    # CONCEPT CLÉ 6: Transparence
    cr.set_source_rgba(1, 0.5, 0, 0.5) # Orange semi-transparent
    cr.rectangle(180, 180, 80, 60)
    cr.fill
  end

  def draw_text_examples(cr, width, height)
    # CONCEPT CLÉ 7: Texte

    cr.set_source_rgb(0, 0, 0)

    # Texte simple
    cr.select_font_face("Sans", Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_NORMAL)
    cr.set_font_size(16)
    cr.move_to(50, 300)
    cr.show_text("Texte simple en Sans")

    # Texte avec style
    cr.select_font_face("Serif", Cairo::FONT_SLANT_ITALIC, Cairo::FONT_WEIGHT_BOLD)
    cr.set_font_size(20)
    cr.move_to(50, 330)
    cr.show_text("Texte en Serif gras italique")

    # Dimensions du texte
    text = "Texte mesuré"
    cr.select_font_face("Sans", Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_NORMAL)
    cr.set_font_size(18)
    extents = cr.text_extents(text)
    cr.move_to(50, 370)
    cr.show_text(text)

    # Cadre autour du texte
    cr.set_source_rgb(0.8, 0.8, 1)
    cr.rectangle(50, 370 - extents.height, extents.width, extents.height)
    cr.stroke
  end

  def draw_interactive_elements(cr, width, height)
    # CONCEPT CLÉ 8: Éléments interactifs

    # Position de la souris
    cr.set_source_rgb(0.5, 0.5, 0.5)
    cr.arc(@mouse_x, @mouse_y, 10, 0, 2 * Math::PI)
    cr.fill

    # Points cliqués
    cr.set_source_rgb(0.8, 0.2, 0.8)
    @click_points.each do |point|
      cr.arc(point[:x], point[:y], 8, 0, 2 * Math::PI)
      cr.fill
    end

    # Ligne reliant les points
    if @click_points.size > 1
      cr.set_source_rgb(0.2, 0.2, 0.2)
      cr.set_line_width(1)
      @click_points.each_with_index do |point, index|
        if index == 0
          cr.move_to(point[:x], point[:y])
        else
          cr.line_to(point[:x], point[:y])
        end
      end
      cr.stroke
    end
  end

  def draw_animation(cr, width, height)
    # CONCEPT CLÉ 9: Animation

    # Carré tournant
    cr.save do  # CONCEPT CLÉ 10: Sauvegarde/restauration du contexte
      cr.translate(600, 100)  # Centre de rotation
      cr.rotate(@animation_angle)

      cr.set_source_rgb(0.2, 0.6, 0.8)
      cr.rectangle(-25, -25, 50, 50)
      cr.fill

      cr.set_source_rgb(0, 0, 0)
      cr.rectangle(-25, -25, 50, 50)
      cr.set_line_width(2)
      cr.stroke
    end

    # Barre de progression animée
    progress = 0.5 + 0.3 * Math.sin(@animation_angle * 2)
    bar_width = 200
    bar_height = 20

    # Fond de la barre
    cr.set_source_rgb(0.8, 0.8, 0.8)
    cr.rectangle(500, 200, bar_width, bar_height)
    cr.fill

    # Progression
    cr.set_source_rgb(0.2, 0.7, 0.2)
    cr.rectangle(500, 200, bar_width * progress, bar_height)
    cr.fill

    # Bordure
    cr.set_source_rgb(0, 0, 0)
    cr.rectangle(500, 200, bar_width, bar_height)
    cr.set_line_width(1)
    cr.stroke
  end

  def on_button_press(widget, event)
    # CONCEPT CLÉ 11: Gestion des clics
    @click_points << { x: event.x, y: event.y }
    widget.queue_draw  # Redessine
  end

  def on_mouse_move(widget, event)
    # CONCEPT CLÉ 12: Suivi de la souris
    @mouse_x = event.x
    @mouse_y = event.y
    widget.queue_draw  # Redessine en continu
  end
end

# Lancement de l'application
win = DrawingAreaTutorial.new
win.signal_connect('destroy') { Gtk.main_quit }
Gtk.main
