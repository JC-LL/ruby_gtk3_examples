require 'gtk3'

class SimpleZoomViewer < Gtk::Window
  def initialize
    super("Vue Zoomée Simple")
    set_default_size(800, 600)

    # Variables d'état
    @mouse_x = 100
    @mouse_y = 100
    @zoom_factor = 3.0
    @cursor_visible = false

    # Créer le conteneur principal
    main_box = Gtk::Box.new(:horizontal, 5)

    # Panneau de gauche : zone de dessin originale
    @drawing_area = Gtk::DrawingArea.new
    @drawing_area.set_size_request(400, 600)

    # Panneau de droite : zone de zoom
    @zoom_area = Gtk::DrawingArea.new
    @zoom_area.set_size_request(400, 600)

    # Connecter les signaux de dessin
    @drawing_area.signal_connect('draw') { |widget, cr| draw_original(cr) }
    @zoom_area.signal_connect('draw') { |widget, cr| draw_zoom(cr) }

    # Suivre le mouvement de la souris
    @drawing_area.add_events(:pointer_motion_mask)
    @drawing_area.signal_connect('motion_notify_event') do |widget, event|
      @mouse_x = event.x
      @mouse_y = event.y
      @cursor_visible = true
      @drawing_area.queue_draw
      @zoom_area.queue_draw
    end

    # Quand la souris quitte la zone
    @drawing_area.signal_connect('leave_notify_event') do |widget, event|
      @cursor_visible = false
      @drawing_area.queue_draw
      @zoom_area.queue_draw
    end

    # Ajouter les contrôles
    main_box.pack_start(@drawing_area, expand: true, fill: true, padding: 0)
    main_box.pack_start(@zoom_area, expand: true, fill: true, padding: 0)

    # Contrôles de zoom
    controls = create_controls
    vbox = Gtk::Box.new(:vertical, 5)
    vbox.pack_start(main_box, expand: true, fill: true, padding: 0)
    vbox.pack_start(controls, expand: false, fill: false, padding: 5)

    add(vbox)

    signal_connect('destroy') { Gtk.main_quit }
    show_all
  end

  def create_controls
    box = Gtk::Box.new(:horizontal, 10)

    # Slider pour le zoom
    label = Gtk::Label.new("Facteur de zoom:")
    zoom_scale = Gtk::Scale.new(:horizontal, 1, 10, 0.5)
    zoom_scale.set_value(@zoom_factor)
    zoom_scale.signal_connect('value_changed') do |scale|
      @zoom_factor = scale.value
      @zoom_area.queue_draw
    end

    box.pack_start(label, expand: false, fill: false, padding: 0)
    box.pack_start(zoom_scale, expand: true, fill: true, padding: 0)

    box
  end

  def draw_original(cr)
    width = 400
    height = 600

    # 1. Fond blanc
    cr.set_source_rgb(1, 1, 1)
    cr.paint

    # 2. Dessiner une grille simple
    cr.set_source_rgb(0.9, 0.9, 0.9)
    cr.set_line_width(1)

    # Lignes verticales
    0.step(width, 20) do |x|
      cr.move_to(x, 0)
      cr.line_to(x, height)
    end

    # Lignes horizontales
    0.step(height, 20) do |y|
      cr.move_to(0, y)
      cr.line_to(width, y)
    end
    cr.stroke

    # 3. Dessiner quelques formes simples
    draw_simple_shapes(cr, width, height)

    # 4. Dessiner le réticule de souris si visible
    if @cursor_visible
      draw_cursor(cr, @mouse_x, @mouse_y)
    end
  end

  def draw_simple_shapes(cr, width, height)
    # 1. Grand rectangle rouge
    cr.set_source_rgb(1, 0, 0)
    cr.rectangle(50, 50, 100, 80)
    cr.fill

    # 2. Cercle vert
    cr.set_source_rgb(0, 1, 0)
    cr.arc(200, 150, 40, 0, 2 * Math::PI)
    cr.fill

    # 3. Triangle bleu
    cr.set_source_rgb(0, 0, 1)
    cr.move_to(300, 100)
    cr.line_to(350, 180)
    cr.line_to(250, 180)
    cr.close_path
    cr.fill

    # 4. Texte
    cr.set_source_rgb(0, 0, 0)
    cr.select_font_face("Sans", Cairo::FONT_SLANT_NORMAL,
                       Cairo::FONT_WEIGHT_BOLD)
    cr.set_font_size(20)
    cr.move_to(100, 300)
    cr.show_text("Déplacez la souris ici")

    cr.set_font_size(14)
    cr.move_to(100, 330)
    cr.show_text("La vue de droite zoome sur la souris")

    # 5. Petit motif de test pour le zoom
    cr.set_source_rgb(0.5, 0.2, 0.8)
    5.times do |i|
      5.times do |j|
        x = 100 + i * 30
        y = 400 + j * 30
        cr.rectangle(x, y, 20, 20)
        cr.fill
      end
    end
  end

  def draw_cursor(cr, x, y)
    # Croix simple pour le curseur
    cr.set_source_rgb(0, 0, 0)
    cr.set_line_width(2)

    # Lignes de la croix
    cr.move_to(x - 10, y)
    cr.line_to(x + 10, y)
    cr.move_to(x, y - 10)
    cr.line_to(x, y + 10)
    cr.stroke

    # Petit cercle au centre
    cr.arc(x, y, 3, 0, 2 * Math::PI)
    cr.fill
  end

  def draw_zoom(cr)
    width = 400
    height = 600

    # 1. Fond gris foncé
    cr.set_source_rgb(0.3, 0.3, 0.3)
    cr.paint

    # 2. Titre
    cr.set_source_rgb(1, 1, 1)
    cr.set_font_size(18)
    cr.move_to(10, 30)
    cr.show_text("VUE ZOOMÉE (x#{@zoom_factor.round(1)})")

    # 3. Zone de zoom (centrée)
    zoom_width = 300
    zoom_height = 300
    zoom_x = (width - zoom_width) / 2
    zoom_y = (height - zoom_height) / 2

    # Fond noir pour la zone de zoom
    cr.set_source_rgb(0, 0, 0)
    cr.rectangle(zoom_x, zoom_y, zoom_width, zoom_height)
    cr.fill

    # SAUVEGARDER l'état avant les transformations
    cr.save

    # 4. Appliquer les transformations pour le zoom
    # a. Déplacer à la position de la zone de zoom
    cr.translate(zoom_x, zoom_y)

    # b. Mettre à l'échelle (ZOOM)
    cr.scale(@zoom_factor, @zoom_factor)

    # c. Centrer sur la position de la souris
    # Nous voulons que la souris soit au centre de la zone zoomée
    # La zone zoomée affiche une zone de taille (zoom_width/zoom_factor) x (zoom_height/zoom_factor)
    visible_width = zoom_width / @zoom_factor
    visible_height = zoom_height / @zoom_factor

    # Décaler pour que la souris soit au centre
    cr.translate(-(@mouse_x - visible_width/2), -(@mouse_y - visible_height/2))

    # 5. Maintenant, dessiner le même contenu que le panneau gauche
    # Mais limité à la zone visible

    # a. Définir un clipping rectangle
    cr.rectangle(0, 0, 400, 600)
    cr.clip

    # b. Dessiner le fond et les formes
    cr.set_source_rgb(1, 1, 1)
    cr.paint

    draw_simple_shapes(cr, 400, 600)

    # c. Dessiner le curseur (position exacte de la souris)
    cr.set_source_rgb(1, 1, 0)  # Jaune pour être visible
    cr.set_line_width(3 / @zoom_factor)  # Ajuster l'épaisseur selon le zoom
    cr.move_to(@mouse_x - 15, @mouse_y)
    cr.line_to(@mouse_x + 15, @mouse_y)
    cr.move_to(@mouse_x, @mouse_y - 15)
    cr.line_to(@mouse_x, @mouse_y + 15)
    cr.stroke

    # RESTAURER l'état (important !)
    cr.restore

    # 6. Cadre autour de la zone de zoom
    cr.set_source_rgb(1, 0.8, 0)
    cr.set_line_width(3)
    cr.rectangle(zoom_x, zoom_y, zoom_width, zoom_height)
    cr.stroke

    # 7. Informations
    cr.set_source_rgb(1, 1, 1)
    cr.set_font_size(12)
    cr.move_to(10, height - 40)
    cr.show_text("Souris: (#{@mouse_x.to_i}, #{@mouse_y.to_i})")

    cr.move_to(10, height - 20)
    visible_area = (zoom_width / @zoom_factor).to_i
    cr.show_text("Zone visible: #{visible_area} × #{visible_area} pixels")
  end
end

# Lancer l'application
app = SimpleZoomViewer.new
Gtk.main
