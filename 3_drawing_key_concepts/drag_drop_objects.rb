require 'gtk3'
require 'cairo'

class DraggableShapesWindow < Gtk::Window
  def initialize
    super(:toplevel)
    set_title("Déplacement d'éléments graphiques avec la souris")
    set_default_size(800, 600)

    @drawing_area = Gtk::DrawingArea.new

    # CONNECTER LES SIGNALS
    @drawing_area.signal_connect('draw') { |widget, cr| on_draw(widget, cr) }
    @drawing_area.signal_connect('button-press-event') { |widget, event| on_button_press(widget, event) }
    @drawing_area.signal_connect('button-release-event') { |widget, event| on_button_release(widget, event) }
    @drawing_area.signal_connect('motion-notify-event') { |widget, event| on_motion_notify(widget, event) }

    # ACTIVER LES ÉVÉNEMENTS DE SOURIS
    @drawing_area.add_events(Gdk::EventMask::BUTTON_PRESS_MASK |
                            Gdk::EventMask::BUTTON_RELEASE_MASK |
                            Gdk::EventMask::POINTER_MOTION_MASK)

    # ÉTAT DE L'APPLICATION
    @shapes = [
      {
        type: :rectangle,
        x: 100, y: 100, width: 120, height: 80,
        color: [0.8, 0.2, 0.2],  # Rouge
        dragged: false
      },
      {
        type: :circle,
        x: 300, y: 150, radius: 50,
        color: [0.2, 0.6, 0.2],  # Vert
        dragged: false
      },
      {
        type: :triangle,
        x: 500, y: 200, size: 80,
        color: [0.2, 0.2, 0.8],  # Bleu
        dragged: false
      }
    ]

    @dragged_shape = nil
    @drag_offset_x = 0
    @drag_offset_y = 0

    add(@drawing_area)
    show_all
  end

  def on_draw(widget, cr)
    width = widget.allocated_width
    height = widget.allocated_height

    # Fond
    cr.set_source_rgb(0.95, 0.95, 0.95)
    cr.paint

    # Instructions
    draw_instructions(cr)

    # Dessiner toutes les formes
    @shapes.each do |shape|
      draw_shape(cr, shape)
    end
  end

  def draw_instructions(cr)
    cr.set_source_rgb(0.2, 0.2, 0.2)
    cr.select_font_face("Sans", Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_NORMAL)
    cr.set_font_size(14)
    cr.move_to(10, 20)
    cr.show_text("Cliquez et glissez pour déplacer les formes")
  end

  def draw_shape(cr, shape)
    case shape[:type]
    when :rectangle
      draw_rectangle(cr, shape)
    when :circle
      draw_circle(cr, shape)
    when :triangle
      draw_triangle(cr, shape)
    end

    # Surligner si dragged
    if shape[:dragged]
      cr.set_source_rgba(1, 1, 0, 0.3)  # Jaune transparent
      case shape[:type]
      when :rectangle
        cr.rectangle(shape[:x] - 5, shape[:y] - 5, shape[:width] + 10, shape[:height] + 10)
      when :circle
        cr.arc(shape[:x], shape[:y], shape[:radius] + 5, 0, 2 * Math::PI)
      when :triangle
        size = shape[:size] + 10
        cr.move_to(shape[:x], shape[:y] - size/2)
        cr.line_to(shape[:x] - size/2, shape[:y] + size/2)
        cr.line_to(shape[:x] + size/2, shape[:y] + size/2)
        cr.close_path
      end
      cr.fill
    end
  end

  def draw_rectangle(cr, shape)
    # Rectangle principal
    cr.set_source_rgb(*shape[:color])
    cr.rectangle(shape[:x], shape[:y], shape[:width], shape[:height])
    cr.fill

    # Bordure
    cr.set_source_rgb(0, 0, 0)
    cr.rectangle(shape[:x], shape[:y], shape[:width], shape[:height])
    cr.set_line_width(2)
    cr.stroke

    # Point de prise
    cr.set_source_rgb(1, 1, 1)
    cr.rectangle(shape[:x] + shape[:width] - 10, shape[:y] + shape[:height] - 10, 8, 8)
    cr.fill
  end

  def draw_circle(cr, shape)
    # Cercle principal
    cr.set_source_rgb(*shape[:color])
    cr.arc(shape[:x], shape[:y], shape[:radius], 0, 2 * Math::PI)
    cr.fill

    # Bordure
    cr.set_source_rgb(0, 0, 0)
    cr.arc(shape[:x], shape[:y], shape[:radius], 0, 2 * Math::PI)
    cr.set_line_width(2)
    cr.stroke

    # Point de prise
    cr.set_source_rgb(1, 1, 1)
    cr.arc(shape[:x] + shape[:radius] * 0.7, shape[:y] + shape[:radius] * 0.7, 4, 0, 2 * Math::PI)
    cr.fill
  end

  def draw_triangle(cr, shape)
    size = shape[:size]

    # Triangle principal
    cr.set_source_rgb(*shape[:color])
    cr.move_to(shape[:x], shape[:y] - size/2)
    cr.line_to(shape[:x] - size/2, shape[:y] + size/2)
    cr.line_to(shape[:x] + size/2, shape[:y] + size/2)
    cr.close_path
    cr.fill

    # Bordure
    cr.set_source_rgb(0, 0, 0)
    cr.move_to(shape[:x], shape[:y] - size/2)
    cr.line_to(shape[:x] - size/2, shape[:y] + size/2)
    cr.line_to(shape[:x] + size/2, shape[:y] + size/2)
    cr.close_path
    cr.set_line_width(2)
    cr.stroke

    # Point de prise
    cr.set_source_rgb(1, 1, 1)
    cr.arc(shape[:x] + size/4, shape[:y] + size/4, 4, 0, 2 * Math::PI)
    cr.fill
  end

  def on_button_press(widget, event)
    # Vérifier si on clique sur une forme
    @shapes.each do |shape|
      if point_in_shape?(event.x, event.y, shape)
        @dragged_shape = shape
        shape[:dragged] = true

        # Calculer l'offset pour un drag fluide
        case shape[:type]
        when :rectangle
          @drag_offset_x = event.x - shape[:x]
          @drag_offset_y = event.y - shape[:y]
        when :circle
          @drag_offset_x = event.x - shape[:x]
          @drag_offset_y = event.y - shape[:y]
        when :triangle
          @drag_offset_x = event.x - shape[:x]
          @drag_offset_y = event.y - shape[:y]
        end

        widget.queue_draw
        break
      end
    end
  end

  def on_button_release(widget, event)
    if @dragged_shape
      @dragged_shape[:dragged] = false
      @dragged_shape = nil
      widget.queue_draw
    end
  end

  def on_motion_notify(widget, event)
    if @dragged_shape
      # Mettre à jour la position de la forme
      case @dragged_shape[:type]
      when :rectangle, :circle, :triangle
        @dragged_shape[:x] = event.x - @drag_offset_x
        @dragged_shape[:y] = event.y - @drag_offset_y
      end

      widget.queue_draw
    end
  end

  def point_in_shape?(x, y, shape)
    case shape[:type]
    when :rectangle
      x.between?(shape[:x], shape[:x] + shape[:width]) &&
      y.between?(shape[:y], shape[:y] + shape[:height])
    when :circle
      distance = Math.sqrt((x - shape[:x])**2 + (y - shape[:y])**2)
      distance <= shape[:radius]
    when :triangle
      # Approximation simple pour un triangle
      size = shape[:size]
      x.between?(shape[:x] - size/2, shape[:x] + size/2) &&
      y.between?(shape[:y] - size/2, shape[:y] + size/2)
    else
      false
    end
  end
end

# EXEMPLE AVANCÉ : Éléments SVG déplaçables
class DraggableSVGWindow < Gtk::Window
  def initialize
    super(:toplevel)
    set_title("Déplacement d'éléments SVG")
    set_default_size(800, 600)

    @drawing_area = Gtk::DrawingArea.new

    # Éléments SVG simulés (en réalité, vous utiliseriez RSVG::Handle)
    @svg_elements = [
      { x: 200, y: 200, width: 100, height: 100, content: "SVG Élément 1", color: [0.9, 0.7, 0.3] },
      { x: 400, y: 300, width: 120, height: 80, content: "SVG Élément 2", color: [0.3, 0.7, 0.9] },
      { x: 100, y: 400, width: 150, height: 60, content: "SVG Élément 3", color: [0.7, 0.3, 0.9] }
    ]

    @dragged_element = nil
    @drag_offset_x = 0
    @drag_offset_y = 0

    @drawing_area.signal_connect('draw') { |widget, cr| draw_svg_elements(widget, cr) }
    @drawing_area.signal_connect('button-press-event') { |widget, event| on_svg_button_press(widget, event) }
    @drawing_area.signal_connect('button-release-event') { |widget, event| on_svg_button_release(widget, event) }
    @drawing_area.signal_connect('motion-notify-event') { |widget, event| on_svg_motion_notify(widget, event) }

    @drawing_area.add_events(Gdk::EventMask::BUTTON_PRESS_MASK |
                            Gdk::EventMask::BUTTON_RELEASE_MASK |
                            Gdk::EventMask::POINTER_MOTION_MASK)

    add(@drawing_area)
    show_all
  end

  def draw_svg_elements(widget, cr)
    # Fond
    cr.set_source_rgb(0.98, 0.98, 0.98)
    cr.paint

    # Dessiner les éléments SVG
    @svg_elements.each do |element|
      # Rectangle de fond (simule un élément SVG)
      cr.set_source_rgb(*element[:color])
      cr.rectangle(element[:x], element[:y], element[:width], element[:height])
      cr.fill

      # Bordure
      cr.set_source_rgb(0, 0, 0)
      cr.rectangle(element[:x], element[:y], element[:width], element[:height])
      cr.set_line_width(1)
      cr.stroke

      # Texte
      cr.set_source_rgb(0, 0, 0)
      cr.select_font_face("Sans", Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_NORMAL)
      cr.set_font_size(12)
      text_extents = cr.text_extents(element[:content])
      text_x = element[:x] + (element[:width] - text_extents.width) / 2
      text_y = element[:y] + (element[:height] + text_extents.height) / 2
      cr.move_to(text_x, text_y)
      cr.show_text(element[:content])

      # Icône de déplacement
      cr.set_source_rgb(0.5, 0.5, 0.5)
      cr.rectangle(element[:x] + element[:width] - 15, element[:y] + 5, 10, 10)
      cr.fill
    end
  end

  def on_svg_button_press(widget, event)
    @svg_elements.each do |element|
      if event.x.between?(element[:x], element[:x] + element[:width]) &&
         event.y.between?(element[:y], element[:y] + element[:height])

        @dragged_element = element
        @drag_offset_x = event.x - element[:x]
        @drag_offset_y = event.y - element[:y]
        break
      end
    end
  end

  def on_svg_button_release(widget, event)
    @dragged_element = nil
  end

  def on_svg_motion_notify(widget, event)
    if @dragged_element
      @dragged_element[:x] = event.x - @drag_offset_x
      @dragged_element[:y] = event.y - @drag_offset_y
      widget.queue_draw
    end
  end
end

# Choix de l'exemple à lancer
puts "Choisissez l'exemple :"
puts "1. Formes géométriques déplaçables"
puts "2. Éléments SVG déplaçables"
print "Votre choix (1 ou 2) : "
choice = gets.chomp

case choice
when "1"
  win = DraggableShapesWindow.new
when "2"
  win = DraggableSVGWindow.new
else
  win = DraggableShapesWindow.new
end

win.signal_connect('destroy') { Gtk.main_quit }
Gtk.main
