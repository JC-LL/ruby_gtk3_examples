require 'gtk3'
require 'rsvg2'
require 'cairo'

class DraggableSVGWindow < Gtk::Window
  def initialize(svg_file)
    super(:toplevel)
    set_title("Déplacement d'objets SVG avec RSVG::Handle")
    set_default_size(800, 600)

    # Charger le SVG
    @svg_handle = RSVG::Handle.new_from_file(svg_file)
    @svg_dimensions = @svg_handle.dimensions

    # Drawing Area
    @drawing_area = Gtk::DrawingArea.new

    # Éléments SVG déplaçables
    @svg_elements = [
      { id: "cercle1", x: 100, y: 100, width: 80, height: 80, type: :circle, original_x: 100, original_y: 100 },
      { id: "rectangle1", x: 200, y: 50, width: 80, height: 60, type: :rect, original_x: 200, original_y: 50 },
      { id: "triangle1", x: 300, y: 200, width: 100, height: 50, type: :polygon, original_x: 300, original_y: 200 },
      { id: "groupe1", x: 50, y: 250, width: 60, height: 40, type: :group, original_x: 50, original_y: 250 },
      { id: "etoile1", x: 350, y: 100, width: 70, height: 105, type: :path, original_x: 350, original_y: 100 }
    ]

    @dragged_element = nil
    @drag_offset_x = 0
    @drag_offset_y = 0

    # Configuration des signaux
    setup_signals

    add(@drawing_area)
    show_all
  end

  def setup_signals
    @drawing_area.signal_connect('draw') { |widget, cr| on_draw(widget, cr) }
    @drawing_area.signal_connect('button-press-event') { |widget, event| on_button_press(widget, event) }
    @drawing_area.signal_connect('button-release-event') { |widget, event| on_button_release(widget, event) }
    @drawing_area.signal_connect('motion-notify-event') { |widget, event| on_motion_notify(widget, event) }

    @drawing_area.add_events(Gdk::EventMask::BUTTON_PRESS_MASK |
                            Gdk::EventMask::BUTTON_RELEASE_MASK |
                            Gdk::EventMask::POINTER_MOTION_MASK)
  end

  def on_draw(widget, cr)
    width = widget.allocated_width
    height = widget.allocated_height

    # Fond
    cr.set_source_rgb(0.95, 0.95, 0.95)
    cr.paint

    # Calcul de l'échelle pour adapter le SVG
    scale_x = width / @svg_dimensions.width.to_f
    scale_y = height / @svg_dimensions.height.to_f
    scale = [scale_x, scale_y].min * 0.8  # 80% de la taille pour la marge

    cr.save do
      # Centrer le SVG
      offset_x = (width - @svg_dimensions.width * scale) / 2
      offset_y = (height - @svg_dimensions.height * scale) / 2
      cr.translate(offset_x, offset_y)
      cr.scale(scale, scale)

      # Dessiner le SVG de base (arrière-plan statique)
      cr.render_rsvg_handle(@svg_handle)

      # Dessiner les éléments déplacés par-dessus
      draw_moved_elements(cr)
    end

    # Dessiner les informations
    draw_info(cr, width, height)
  end

  def draw_moved_elements(cr)
    @svg_elements.each do |element|
      next unless element[:moved]  # Ne dessiner que les éléments déplacés

      cr.save do
        # Appliquer la transformation de position
        cr.translate(element[:x] - element[:original_x], element[:y] - element[:original_y])

        # Dessiner uniquement l'élément spécifique en utilisant son ID
        draw_svg_element_by_id(cr, element[:id])
      end

      # Dessiner un cadre de sélection si l'élément est sélectionné
      if element == @dragged_element
        draw_selection_highlight(cr, element)
      end
    end
  end

  def draw_svg_element_by_id(cr, element_id)
    # Cette méthode utilise une astuce : on ne peut pas facilement dessiner
    # un seul élément SVG avec RSVG, donc on utilise un contexte temporaire
    # Pour une vraie application, vous devriez parser le SVG et gérer les éléments séparément

    # Pour cet exemple, on va simuler le rendu en dessinant des formes simples
    case element_id
    when "cercle1"
      cr.set_source_rgb(1, 0, 0)  # Rouge
      cr.arc(100, 100, 40, 0, 2 * Math::PI)
      cr.fill
      cr.set_source_rgb(0, 0, 0)
      cr.arc(100, 100, 40, 0, 2 * Math::PI)
      cr.set_line_width(2)
      cr.stroke

    when "rectangle1"
      cr.set_source_rgb(0, 0, 1)  # Bleu
      cr.rectangle(200, 50, 80, 60)
      cr.fill
      cr.set_source_rgb(0, 0, 0)
      cr.rectangle(200, 50, 80, 60)
      cr.set_line_width(2)
      cr.stroke

    when "triangle1"
      cr.set_source_rgb(0, 1, 0)  # Vert
      cr.move_to(300, 200)
      cr.line_to(350, 250)
      cr.line_to(250, 250)
      cr.close_path
      cr.fill
      cr.set_source_rgb(0, 0, 0)
      cr.move_to(300, 200)
      cr.line_to(350, 250)
      cr.line_to(250, 250)
      cr.close_path
      cr.set_line_width(2)
      cr.stroke

    when "groupe1"
      cr.save do
        cr.translate(50, 250)
        cr.set_source_rgb(0.5, 0, 0.5)  # Violet
        cr.rectangle(0, 0, 60, 40)
        cr.fill
        cr.set_source_rgb(1, 1, 0)  # Jaune
        cr.arc(30, 20, 15, 0, 2 * Math::PI)
        cr.fill
      end

    when "etoile1"
      cr.set_source_rgb(1, 0.5, 0)  # Orange
      # Étoile simplifiée
      cr.move_to(350, 100)
      cr.line_to(365, 140)
      cr.line_to(405, 140)
      cr.line_to(375, 165)
      cr.line_to(385, 205)
      cr.line_to(350, 180)
      cr.line_to(315, 205)
      cr.line_to(325, 165)
      cr.line_to(295, 140)
      cr.line_to(335, 140)
      cr.close_path
      cr.fill
    end
  end

  def draw_selection_highlight(cr, element)
    cr.set_source_rgba(1, 1, 0, 0.3)  # Jaune transparent
    cr.rectangle(element[:x] - 5, element[:y] - 5, element[:width] + 10, element[:height] + 10)
    cr.fill

    cr.set_source_rgb(1, 0.5, 0)
    cr.rectangle(element[:x] - 5, element[:y] - 5, element[:width] + 10, element[:height] + 10)
    cr.set_line_width(2)
    cr.set_dash([5.0, 3.0])
    cr.stroke
    cr.set_dash([])
  end

  def draw_info(cr, width, height)
    cr.set_source_rgb(0.2, 0.2, 0.2)
    cr.select_font_face("Sans", Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_NORMAL)
    cr.set_font_size(12)

    info = "Cliquez et glissez pour déplacer les objets SVG"
    cr.move_to(10, height - 30)
    cr.show_text(info)

    if @dragged_element
      status = "Déplacement: #{@dragged_element[:id]} - Position: #{@dragged_element[:x].to_i}, #{@dragged_element[:y].to_i}"
      cr.move_to(10, height - 15)
      cr.show_text(status)
    end
  end

  def on_button_press(widget, event)
    # Convertir les coordonnées de l'écran vers les coordonnées SVG
    svg_x, svg_y = screen_to_svg_coords(event.x, event.y)

    # Chercher l'élément cliqué
    @svg_elements.each do |element|
      if point_in_element?(svg_x, svg_y, element)
        @dragged_element = element
        @drag_offset_x = svg_x - element[:x]
        @drag_offset_y = svg_y - element[:y]
        element[:moved] = true
        widget.queue_draw
        break
      end
    end
  end

  def on_button_release(widget, event)
    @dragged_element = nil
    widget.queue_draw
  end

  def on_motion_notify(widget, event)
    if @dragged_element
      svg_x, svg_y = screen_to_svg_coords(event.x, event.y)
      @dragged_element[:x] = svg_x - @drag_offset_x
      @dragged_element[:y] = svg_y - @drag_offset_y
      widget.queue_draw
    end
  end

  def screen_to_svg_coords(screen_x, screen_y)
    width = @drawing_area.allocated_width
    height = @drawing_area.allocated_height

    scale_x = width / @svg_dimensions.width.to_f
    scale_y = height / @svg_dimensions.height.to_f
    scale = [scale_x, scale_y].min * 0.8

    offset_x = (width - @svg_dimensions.width * scale) / 2
    offset_y = (height - @svg_dimensions.height * scale) / 2

    # Convertir les coordonnées écran vers coordonnées SVG
    svg_x = (screen_x - offset_x) / scale
    svg_y = (screen_y - offset_y) / scale

    [svg_x, svg_y]
  end

  def point_in_element?(x, y, element)
    x.between?(element[:x], element[:x] + element[:width]) &&
    y.between?(element[:y], element[:y] + element[:height])
  end
end

# VERSION AVANCÉE : Avec un vrai parsing SVG
class AdvancedDraggableSVGWindow < Gtk::Window
  def initialize(svg_file)
    super(:toplevel)
    set_title("Déplacement SVG Avancé - Vrai parsing")
    set_default_size(800, 600)

    @svg_handle = RSVG::Handle.new_from_file(svg_file)
    @svg_dimensions = @svg_handle.dimensions

    # Parser le SVG pour extraire les éléments
    @svg_elements = parse_svg_elements(svg_file)

    @drawing_area = Gtk::DrawingArea.new
    @dragged_element = nil

    setup_signals
    add(@drawing_area)
    show_all
  end

  def parse_svg_elements(svg_file)
    elements = []

    # Lecture manuelle du fichier SVG pour extraire les éléments
    # Dans une vraie application, utilisez nokogiri ou autre parser XML
    File.readlines(svg_file).each_with_index do |line, index|
      if line.include?('id="')
        id = line.match(/id="([^"]+)"/)&.[](1)
        next unless id

        # Extraire les coordonnées approximatives
        case line
        when /<circle/
          cx = line.match(/cx="([^"]+)"/)&.[](1)&.to_f || 0
          cy = line.match(/cy="([^"]+)"/)&.[](1)&.to_f || 0
          r = line.match(/r="([^"]+)"/)&.[](1)&.to_f || 0
          elements << {
            id: id, type: :circle,
            x: cx - r, y: cy - r, width: r * 2, height: r * 2,
            original_x: cx - r, original_y: cy - r,
            cx: cx, cy: cy, r: r
          }

        when /<rect/
          x = line.match(/x="([^"]+)"/)&.[](1)&.to_f || 0
          y = line.match(/y="([^"]+)"/)&.[](1)&.to_f || 0
          width = line.match(/width="([^"]+)"/)&.[](1)&.to_f || 0
          height = line.match(/height="([^"]+)"/)&.[](1)&.to_f || 0
          elements << {
            id: id, type: :rect,
            x: x, y: y, width: width, height: height,
            original_x: x, original_y: y
          }
        end
      end
    end

    elements
  end

  def setup_signals
    @drawing_area.signal_connect('draw') { |widget, cr| on_draw(widget, cr) }
    @drawing_area.signal_connect('button-press-event') { |widget, event| on_button_press(widget, event) }
    @drawing_area.signal_connect('button-release-event') { |widget, event| on_button_release(widget, event) }
    @drawing_area.signal_connect('motion-notify-event') { |widget, event| on_motion_notify(widget, event) }

    @drawing_area.add_events(Gdk::EventMask::BUTTON_PRESS_MASK |
                            Gdk::EventMask::BUTTON_RELEASE_MASK |
                            Gdk::EventMask::POINTER_MOTION_MASK)
  end

  def on_draw(widget, cr)
    width = widget.allocated_width
    height = widget.allocated_height

    cr.set_source_rgb(0.98, 0.98, 0.98)
    cr.paint

    scale_x = width / @svg_dimensions.width.to_f
    scale_y = height / @svg_dimensions.height.to_f
    scale = [scale_x, scale_y].min * 0.8

    cr.save do
      offset_x = (width - @svg_dimensions.width * scale) / 2
      offset_y = (height - @svg_dimensions.height * scale) / 2
      cr.translate(offset_x, offset_y)
      cr.scale(scale, scale)

      # Dessiner le SVG original en arrière-plan (estompé)
      cr.save do
        cr.set_source_rgba(0.7, 0.7, 0.7, 0.3)
        cr.render_rsvg_handle(@svg_handle)
      end

      # Dessiner les éléments déplacés
      @svg_elements.each do |element|
        next unless element[:moved]

        cr.save do
          delta_x = element[:x] - element[:original_x]
          delta_y = element[:y] - element[:original_y]
          cr.translate(delta_x, delta_y)
          draw_svg_element(cr, element)
        end
      end
    end

    draw_ui_overlay(cr, width, height)
  end

  def draw_svg_element(cr, element)
    case element[:type]
    when :circle
      cr.set_source_rgb(1, 0, 0)
      cr.arc(element[:cx], element[:cy], element[:r], 0, 2 * Math::PI)
      cr.fill
      cr.set_source_rgb(0, 0, 0)
      cr.arc(element[:cx], element[:cy], element[:r], 0, 2 * Math::PI)
      cr.set_line_width(2)
      cr.stroke
    when :rect
      cr.set_source_rgb(0, 0, 1)
      cr.rectangle(element[:x], element[:y], element[:width], element[:height])
      cr.fill
      cr.set_source_rgb(0, 0, 0)
      cr.rectangle(element[:x], element[:y], element[:width], element[:height])
      cr.set_line_width(2)
      cr.stroke
    end
  end

  def draw_ui_overlay(cr, width, height)
    cr.set_source_rgb(0.2, 0.2, 0.2)
    cr.select_font_face("Sans", Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_NORMAL)
    cr.set_font_size(14)

    cr.move_to(10, 25)
    cr.show_text("Déplacement d'objets SVG avec RSVG::Handle")

    cr.set_font_size(12)
    cr.move_to(10, height - 10)

    if @dragged_element
      cr.show_text("Déplacement: #{@dragged_element[:id]} - Usez la souris pour déplacer")
    else
      cr.show_text("Cliquez sur un objet SVG pour le déplacer")
    end
  end

  def on_button_press(widget, event)
    svg_x, svg_y = screen_to_svg_coords(event.x, event.y)

    @svg_elements.each do |element|
      if point_in_element?(svg_x, svg_y, element)
        @dragged_element = element
        @drag_offset_x = svg_x - element[:x]
        @drag_offset_y = svg_y - element[:y]
        element[:moved] = true
        widget.queue_draw
        break
      end
    end
  end

  def on_button_release(widget, event)
    @dragged_element = nil
    widget.queue_draw
  end

  def on_motion_notify(widget, event)
    if @dragged_element
      svg_x, svg_y = screen_to_svg_coords(event.x, event.y)
      @dragged_element[:x] = svg_x - @drag_offset_x
      @dragged_element[:y] = svg_y - @drag_offset_y
      widget.queue_draw
    end
  end

  def screen_to_svg_coords(screen_x, screen_y)
    width = @drawing_area.allocated_width
    height = @drawing_area.allocated_height

    scale_x = width / @svg_dimensions.width.to_f
    scale_y = height / @svg_dimensions.height.to_f
    scale = [scale_x, scale_y].min * 0.8

    offset_x = (width - @svg_dimensions.width * scale) / 2
    offset_y = (height - @svg_dimensions.height * scale) / 2

    svg_x = (screen_x - offset_x) / scale
    svg_y = (screen_y - offset_y) / scale

    [svg_x, svg_y]
  end

  def point_in_element?(x, y, element)
    x.between?(element[:x], element[:x] + element[:width]) &&
    y.between?(element[:y], element[:y] + element[:height])
  end
end

# Lancement de l'application
if ARGV[0] && File.exist?(ARGV[0])
  svg_file = ARGV[0]
else
  # Créer un fichier SVG par défaut si aucun n'est fourni
  svg_file = "mon_dessin.svg"
  unless File.exist?(svg_file)
    File.write(svg_file, <<~SVG
      <?xml version="1.0" encoding="UTF-8"?>
      <svg width="400" height="400" xmlns="http://www.w3.org/2000/svg">
          <circle id="cercle1" cx="100" cy="100" r="40" fill="red" stroke="black" stroke-width="2"/>
          <rect id="rectangle1" x="200" y="50" width="80" height="60" fill="blue" stroke="black" stroke-width="2"/>
          <polygon id="triangle1" points="300,200 350,250 250,250" fill="green" stroke="black" stroke-width="2"/>
      </svg>
    SVG
    )
    puts "Fichier SVG créé: #{svg_file}"
  end
end

begin
  # Utiliser la version avancée
  win = AdvancedDraggableSVGWindow.new(svg_file)
  win.signal_connect('destroy') { Gtk.main_quit }
  Gtk.main
rescue => e
  puts "Erreur: #{e.message}"
  puts "Assurez-vous que le fichier SVG existe et est valide."
end
