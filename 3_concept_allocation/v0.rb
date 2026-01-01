require "gtk3"

class AdaptiveChart < Gtk::Window
  def initialize
    super("Diagramme Adaptatif")
    set_default_size(600, 400)

    @data = [30, 45, 25, 60, 35, 50, 40, 55]

    @area = Gtk::DrawingArea.new
    @area.signal_connect('draw') { |w, cr| draw_chart(w, cr) }

    # Contrôles pour modifier les données
    controls = create_controls

    vbox = Gtk::Box.new(:vertical, 5)
    vbox.pack_start(@area, expand: true, fill: true, padding: 0)
    vbox.pack_start(controls, expand: false, fill: false, padding: 5)

    add(vbox)
    show_all
  end

  def create_controls
    hbox = Gtk::Box.new(:horizontal, 10)

    add_button = Gtk::Button.new(label: "Ajouter donnée")
    add_button.signal_connect('clicked') do
      @data << rand(20..80)
      @area.queue_draw
    end

    remove_button = Gtk::Button.new(label: "Supprimer donnée")
    remove_button.signal_connect('clicked') do
      @data.pop if @data.size > 1
      @area.queue_draw
    end

    hbox.pack_start(add_button, expand: false, fill: false, padding: 0)
    hbox.pack_start(remove_button, expand: false, fill: false, padding: 0)

    hbox
  end

  def draw_chart(widget, cr)
    w = widget.allocated_width.to_f
    h = widget.allocated_height.to_f

    # Marges
    margin_top = h * 0.1
    margin_bottom = h * 0.2
    margin_left = w * 0.15
    margin_right = w * 0.05

    # Zone du graphique
    chart_w = w - margin_left - margin_right
    chart_h = h - margin_top - margin_bottom

    # Échelle verticale
    max_value = @data.max.to_f
    min_value = @data.min.to_f
    range = max_value - min_value
    range = 1 if range == 0  # Éviter division par zéro

    # Fond
    cr.set_source_rgb(1, 1, 1)
    cr.paint

    # Zone du graphique
    cr.set_source_rgb(0.95, 0.95, 0.95)
    cr.rectangle(margin_left, margin_top, chart_w, chart_h)
    cr.fill

    # Grille
    draw_grid(cr, margin_left, margin_top, chart_w, chart_h, max_value, min_value)

    # Ligne du graphique
    draw_data_line(cr, margin_left, margin_top, chart_w, chart_h, max_value, min_value)

    # Axes
    draw_axes(cr, margin_left, margin_top, chart_w, chart_h, max_value, min_value)

    # Titre et légendes
    draw_labels(cr, w, h, margin_left, margin_top, chart_w, chart_h)
  end

  def draw_grid(cr, x, y, width, height, max_val, min_val)
    cr.set_source_rgba(0.8, 0.8, 0.8, 0.5)
    cr.set_line_width(1)

    # Lignes horizontales (niveaux de valeur)
    5.times do |i|
      level = i / 4.0  # 0, 0.25, 0.5, 0.75, 1
      value = min_val + (max_val - min_val) * level
      y_pos = y + height * (1 - level)

      cr.move_to(x, y_pos)
      cr.line_to(x + width, y_pos)

      # Label de valeur
      cr.save
      cr.set_source_rgb(0.3, 0.3, 0.3)
      cr.set_font_size(10)
      cr.move_to(x - 40, y_pos + 4)
      cr.show_text("#{value.round(1)}")
      cr.restore
    end
    cr.stroke
  end

  def draw_data_line(cr, x, y, width, height, max_val, min_val)
    return if @data.empty?

    point_radius = [width / @data.size / 4, 5].min
    point_radius = [point_radius, 3].max

    # Ligne
    cr.set_source_rgb(0.2, 0.4, 0.8)
    cr.set_line_width(2)

    @data.each_with_index do |value, i|
      x_pos = x + (i.to_f / (@data.size - 1)) * width
      y_pos = y + height * (1 - (value - min_val) / (max_val - min_val))

      if i == 0
        cr.move_to(x_pos, y_pos)
      else
        cr.line_to(x_pos, y_pos)
      end
    end
    cr.stroke

    # Points
    @data.each_with_index do |value, i|
      x_pos = x + (i.to_f / (@data.size - 1)) * width
      y_pos = y + height * (1 - (value - min_val) / (max_val - min_val))

      cr.set_source_rgb(0.8, 0.2, 0.2)
      cr.arc(x_pos, y_pos, point_radius, 0, 2 * Math::PI)
      cr.fill

      # Valeur au-dessus du point
      cr.set_source_rgb(0, 0, 0)
      cr.set_font_size(point_radius * 1.5)
      text = value.to_i.to_s
      extents = cr.text_extents(text)
      cr.move_to(x_pos - extents.width/2, y_pos - point_radius - 5)
      cr.show_text(text)
    end
  end

  def draw_axes(cr, x, y, width, height, max_val, min_val)
    cr.set_source_rgb(0, 0, 0)
    cr.set_line_width(2)

    # Axe Y
    cr.move_to(x, y)
    cr.line_to(x, y + height)

    # Axe X
    cr.move_to(x, y + height)
    cr.line_to(x + width, y + height)

    # Flèches
    # Flèche Y
    cr.move_to(x, y)
    cr.line_to(x - 5, y + 10)
    cr.move_to(x, y)
    cr.line_to(x + 5, y + 10)

    # Flèche X
    cr.move_to(x + width, y + height)
    cr.line_to(x + width - 10, y + height - 5)
    cr.move_to(x + width, y + height)
    cr.line_to(x + width - 10, y + height + 5)

    cr.stroke
  end

  def draw_labels(cr, total_w, total_h, x, y, width, height)
    # Titre
    cr.set_source_rgb(0, 0, 0)
    cr.set_font_size(16)
    cr.select_font_face("Sans", Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_BOLD)

    title = "Graphique Adaptatif (#{@data.size} points)"
    extents = cr.text_extents(title)
    cr.move_to((total_w - extents.width)/2, y - 20)
    cr.show_text(title)

    # Labels axes
    cr.set_font_size(12)
    cr.move_to(x + width + 10, y + height + 20)
    cr.show_text("Index")

    cr.save
    cr.translate(x - 40, y + height/2)
    cr.rotate(-Math::PI/2)
    cr.move_to(0, 0)
    cr.show_text("Valeur")
    cr.restore

    # Infos
    cr.set_font_size(10)
    info = "Taille: #{total_w.to_i}×#{total_h.to_i} | Données: #{@data.min} - #{@data.max}"
    cr.move_to(x, y + height + 40)
    cr.show_text(info)
  end
end

AdaptiveChart.new
Gtk.main
