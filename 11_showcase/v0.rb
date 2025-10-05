#!/usr/bin/env ruby

require 'gtk3'
require 'cairo'

class Gtk3Showcase
  def initialize
    @window = Gtk::Window.new
    setup_main_window
    create_ui
    connect_signals
  end

  def show
    @window.show_all
  end

  private

  def setup_main_window
    @window.set_title("Ruby/GTK3 Showcase - Démonstration Avancée")
    @window.set_default_size(1200, 800)
    @window.set_position(Gtk::WindowPosition::CENTER)

    # Application icon
    begin
      @window.set_icon_from_file("icon.png") if File.exist?("icon.png")
    rescue
      # Ignorer si l'icône n'est pas disponible
    end
  end

  def create_ui
    # Conteneur principal
    main_box = Gtk::Box.new(:vertical, 0)
    @window.add(main_box)

    # Panneau redimensionnable principal
    @main_paned = Gtk::Paned.new(:horizontal)
    main_box.pack_start(@main_paned, expand: true, fill: true, padding: 0)

    create_sidebar
    create_main_content

    # Barre de status
    create_statusbar(main_box)
  end

  def create_sidebar
    # Sidebar avec plusieurs sections
    @sidebar = Gtk::Box.new(:vertical, 5)
    @sidebar.set_size_request(250, -1)

    # Section contrôles
    controls_frame = Gtk::Frame.new("Contrôles Interactifs")
    controls_frame.set_margin_top(5)
    controls_frame.set_margin_bottom(5)
    controls_frame.set_margin_start(5)
    controls_frame.set_margin_end(5)
    controls_box = Gtk::Box.new(:vertical, 5)
    controls_frame.add(controls_box)

    # Curseur avec valeur dynamique
    @slider = Gtk::Scale.new(:horizontal, 0, 100, 1)
    @slider.value = 50
    @slider_label = Gtk::Label.new("Valeur curseur: 50")
    controls_box.pack_start(@slider_label, expand: false, fill: false, padding: 5)
    controls_box.pack_start(@slider, expand: false, fill: false, padding: 5)

    # Bouton toggle
    @toggle_btn = Gtk::ToggleButton.new(label: "Mode Animation")
    controls_box.pack_start(@toggle_btn, expand: false, fill: false, padding: 5)

    # Sélecteur de couleur
    @color_btn = Gtk::ColorButton.new
    @color_btn.title = "Choisir une couleur"
    @color_btn.rgba = Gdk::RGBA.new(0.8, 0.2, 0.2, 1.0)
    controls_box.pack_start(@color_btn, expand: false, fill: false, padding: 5)

    # Liste déroulante
    @combo = Gtk::ComboBoxText.new
    @combo.append_text("Forme: Cercle")
    @combo.append_text("Forme: Carré")
    @combo.append_text("Forme: Triangle")
    @combo.active = 0
    controls_box.pack_start(@combo, expand: false, fill: false, padding: 5)

    # Boutons avec icônes
    btn_box = Gtk::ButtonBox.new(:vertical)
    btn_box.layout_style = :spread
    btn_box.set_spacing(5)

    @reset_btn = Gtk::Button.new(label: " Réinitialiser ")
    @reset_btn.image = Gtk::Image.new(icon_name: "view-refresh", size: :button)

    @info_btn = Gtk::Button.new(label: " Informations ")
    @info_btn.image = Gtk::Image.new(icon_name: "dialog-information", size: :button)

    btn_box.pack_start(@reset_btn, expand: false, fill: false, padding: 2)
    btn_box.pack_start(@info_btn, expand: false, fill: false, padding: 2)
    controls_box.pack_start(btn_box, expand: false, fill: false, padding: 5)

    # Section informations
    info_frame = Gtk::Frame.new("Informations Dynamiques")
    info_frame.set_margin_top(5)
    info_frame.set_margin_bottom(5)
    info_frame.set_margin_start(5)
    info_frame.set_margin_end(5)
    info_box = Gtk::Box.new(:vertical, 5)
    info_frame.add(info_box)

    @fps_label = Gtk::Label.new("FPS: --")
    @mouse_label = Gtk::Label.new("Souris: (0, 0)")
    @time_label = Gtk::Label.new("Temps: --")

    info_box.pack_start(@fps_label, expand: false, fill: false, padding: 5)
    info_box.pack_start(@mouse_label, expand: false, fill: false, padding: 5)
    info_box.pack_start(@time_label, expand: false, fill: false, padding: 5)

    # Empilement de la sidebar
    @sidebar.pack_start(controls_frame, expand: false, fill: false, padding: 0)
    @sidebar.pack_start(info_frame, expand: false, fill: false, padding: 0)

    @main_paned.pack1(@sidebar, resize: false, shrink: false)
  end

  def create_main_content
    # Zone de contenu principale avec notebook (onglets)
    @notebook = Gtk::Notebook.new
    @notebook.set_tab_pos(:top)

    # Premier onglet: Canvas de dessin
    create_canvas_tab

    # Deuxième onglet: Grille de données
    create_grid_tab

    # Troisième onglet: Zone de texte
    create_text_tab

    @main_paned.pack2(@notebook, resize: true, shrink: false)
  end

  def create_canvas_tab
    canvas_box = Gtk::Box.new(:vertical, 5)

    # Barre d'outils pour le canvas
    tool_bar = Gtk::Box.new(:horizontal, 5)
    tool_bar.set_margin_top(5)
    tool_bar.set_margin_start(5)
    tool_bar.set_margin_end(5)

    @draw_btn = Gtk::ToggleButton.new(label: " Mode Dessin ")
    @clear_btn = Gtk::Button.new(label: " Effacer ")

    tool_bar.pack_start(@draw_btn, expand: false, fill: false, padding: 0)
    tool_bar.pack_start(@clear_btn, expand: false, fill: false, padding: 0)
    tool_bar.pack_start(Gtk::Label.new(""), expand: true, fill: true, padding: 0) # Spacer

    canvas_box.pack_start(tool_bar, expand: false, fill: false, padding: 0)

    # Canvas de dessin personnalisé
    @canvas = Gtk::DrawingArea.new
    @canvas.set_size_request(600, 400)
    @canvas.signal_connect('draw') { |widget, cr| draw_canvas(widget, cr) }

    # Variables pour l'animation et le dessin
    @animation_angle = 0
    @particles = []
    @drawing_mode = false
    @mouse_trail = []

    # Configuration des événements de souris
    @canvas.add_events(Gdk::EventMask::BUTTON_PRESS_MASK |
                      Gdk::EventMask::BUTTON_RELEASE_MASK |
                      Gdk::EventMask::POINTER_MOTION_MASK)

    # Scroll pour le canvas
    scrolled_window = Gtk::ScrolledWindow.new
    scrolled_window.set_policy(:automatic, :automatic)
    scrolled_window.add(@canvas)

    canvas_box.pack_start(scrolled_window, expand: true, fill: true, padding: 5)

    # Ajout de l'onglet
    @notebook.append_page(canvas_box, Gtk::Label.new("🎨 Canvas Animé"))
  end

  def create_grid_tab
    # Création d'un treeview avec liste modèle
    grid_box = Gtk::Box.new(:vertical, 5)

    # Modèle de données
    @list_store = Gtk::ListStore.new(String, Integer, String)

    # Ajout de données d'exemple
    10.times do |i|
      iter = @list_store.append
      @list_store.set_value(iter, 0, "Élément #{i + 1}")
      @list_store.set_value(iter, 1, rand(1000))
      @list_store.set_value(iter, 2, ["🟢 Actif", "🔴 Inactif", "🟡 En pause"].sample)
    end

    # Création du treeview
    @tree_view = Gtk::TreeView.new(@list_store)

    # Colonnes
    renderer = Gtk::CellRendererText.new
    col1 = Gtk::TreeViewColumn.new("Nom", renderer, text: 0)
    col2 = Gtk::TreeViewColumn.new("Valeur", renderer, text: 1)
    col3 = Gtk::TreeViewColumn.new("Statut", renderer, text: 2)

    @tree_view.append_column(col1)
    @tree_view.append_column(col2)
    @tree_view.append_column(col3)

    # Scroll pour le treeview
    scrolled_window = Gtk::ScrolledWindow.new
    scrolled_window.set_policy(:automatic, :automatic)
    scrolled_window.add(@tree_view)

    grid_box.pack_start(scrolled_window, expand: true, fill: true, padding: 5)

    @notebook.append_page(grid_box, Gtk::Label.new("📊 Données Structurées"))
  end

  def create_text_tab
    text_box = Gtk::Box.new(:vertical, 5)

    # Zone de texte avec syntax highlighting simulé
    @text_view = Gtk::TextView.new
    @text_view.wrap_mode = :word
    @text_buffer = @text_view.buffer

    # Configuration du texte d'exemple
    sample_code = <<~RUBY
      # Ruby/GTK3 Showcase - Démonstration
      class Showcase
        def initialize
          @features = {
            canvas: "Dessin vectoriel avec Cairo",
            animation: "Système de particules temps réel",
            widgets: "Contrôles interactifs variés",
            layout: "Panneaux redimensionnables",
            data: "Affichage de données structurées"
          }
        end

        def draw_animation(cr, width, height)
          # Dessin d'un cercle animé
          cr.set_source_rgb(0.2, 0.4, 0.8)
          cr.arc(width/2, height/2, 100, 0, 2 * Math::PI)
          cr.fill
        end

        def run
          puts "Application Ruby/GTK3 démarrée !"
        end
      end

      # Lancement
      app = Showcase.new
      app.run
    RUBY

    @text_buffer.text = sample_code

    # Scroll pour la zone de texte
    scrolled_window = Gtk::ScrolledWindow.new
    scrolled_window.set_policy(:automatic, :automatic)
    scrolled_window.add(@text_view)

    text_box.pack_start(scrolled_window, expand: true, fill: true, padding: 5)

    @notebook.append_page(text_box, Gtk::Label.new("📝 Éditeur de Code"))
  end

  def create_statusbar(parent_box)
    # Barre de status en bas de la fenêtre
    @statusbar = Gtk::Statusbar.new
    @statusbar_context = @statusbar.get_context_id("main")
    @statusbar.push(@statusbar_context, "✅ Prêt - Ruby/GTK3 Showcase démarré avec succès")

    parent_box.pack_start(@statusbar, expand: false, fill: false, padding: 0)
  end

  def connect_signals
    # Connexion des signaux pour l'interactivité

    # Curseur
    @slider.signal_connect('value-changed') do
      value = @slider.value.to_i
      @slider_label.text = "Valeur curseur: #{value}"
      @canvas.queue_draw if @canvas
    end

    # Animation
    @toggle_btn.signal_connect('toggled') do
      if @toggle_btn.active?
        start_animation
        @statusbar.push(@statusbar_context, "🎬 Animation démarrée")
      else
        stop_animation
        @statusbar.push(@statusbar_context, "⏹️ Animation arrêtée")
      end
    end

    # Événements canvas
    @canvas.signal_connect('motion-notify-event') do |_, event|
      x, y = event.x, event.y
      @mouse_label.text = "Souris: (#{x.to_i}, #{y.to_i})"

      if @drawing_mode
        @mouse_trail << [x, y] if @mouse_trail.size < 100
        @canvas.queue_draw
      end
    end

    @canvas.signal_connect('button-press-event') do |_, event|
      if event.button == 1 # Clic gauche
        @drawing_mode = true
        @mouse_trail.clear
        @statusbar.push(@statusbar_context, "✏️ Mode dessin activé")
      end
    end

    @canvas.signal_connect('button-release-event') do |_, event|
      if event.button == 1
        @drawing_mode = false
        @statusbar.push(@statusbar_context, "📋 Mode dessin désactivé")
      end
    end

    # Liste déroulante
    @combo.signal_connect('changed') do
      @canvas.queue_draw if @canvas
      shape_name = @combo.active_text.split(":").last.strip
      @statusbar.push(@statusbar_context, "🔷 Forme changée: #{shape_name}")
    end

    # Sélecteur de couleur
    @color_btn.signal_connect('color-set') do
      @canvas.queue_draw if @canvas
      color = @color_btn.rgba
      @statusbar.push(@statusbar_context, "🎨 Couleur sélectionnée")
    end

    # Bouton reset
    @reset_btn.signal_connect('clicked') do
      @slider.value = 50
      @mouse_trail.clear
      @particles.clear
      @animation_angle = 0
      @combo.active = 0
      @color_btn.rgba = Gdk::RGBA.new(0.8, 0.2, 0.2, 1.0)
      @toggle_btn.active = false
      @draw_btn.active = false
      @drawing_mode = false
      @canvas.queue_draw if @canvas
      @statusbar.push(@statusbar_context, "🔄 Réinitialisation effectuée")
    end

    # Bouton info
    @info_btn.signal_connect('clicked') do
      show_info_dialog
    end

    # Bouton dessiner
    @draw_btn.signal_connect('toggled') do
      @drawing_mode = @draw_btn.active?
      status = @drawing_mode ? "activé" : "désactivé"
      @statusbar.push(@statusbar_context, "✏️ Mode dessin #{status}")
    end

    # Bouton effacer
    @clear_btn.signal_connect('clicked') do
      @mouse_trail.clear
      @particles.clear
      @canvas.queue_draw if @canvas
      @statusbar.push(@statusbar_context, "🧹 Canvas effacé")
    end

    # Fermeture de la fenêtre
    @window.signal_connect('destroy') do
      stop_animation
      Gtk.main_quit
    end

    # Mise à jour du temps
    GLib::Timeout.add(1000) do
      update_time
      true
    end
  end

  def draw_canvas(widget, cr)
    width = widget.allocated_width
    height = widget.allocated_height

    # Fond dégradé
    pattern = Cairo::LinearPattern.new(0, 0, 0, height)
    pattern.add_color_stop_rgb(0, 0.1, 0.1, 0.2)
    pattern.add_color_stop_rgb(1, 0.3, 0.3, 0.4)
    cr.set_source(pattern)
    cr.paint

    # Dessin basé sur le sélecteur
    case @combo.active
    when 0
      draw_circle(cr, width, height)
    when 1
      draw_square(cr, width, height)
    when 2
      draw_triangle(cr, width, height)
    end

    # Trail de souris
    draw_mouse_trail(cr)

    # Particules (si animation active)
    draw_particles(cr) if @toggle_btn.active?
  end

  def draw_circle(cr, width, height)
    center_x = width / 2
    center_y = height / 2
    radius = [width, height].min / 4 * (@slider.value / 100.0)

    # Utiliser la couleur sélectionnée
    color = @color_btn.rgba
    cr.set_source_rgb(color.red, color.green, color.blue)
    cr.arc(center_x, center_y, radius, 0, 2 * Math::PI)
    cr.fill

    # Animation de rotation
    if @toggle_btn.active?
      cr.set_source_rgb(1 - color.red, 1 - color.green, 1 - color.blue)
      cr.set_line_width(3)
      cr.arc(center_x, center_y, radius + 20, @animation_angle, @animation_angle + Math::PI / 2)
      cr.stroke
    end
  end

  def draw_square(cr, width, height)
    size = [width, height].min / 3 * (@slider.value / 100.0)
    x = (width - size) / 2
    y = (height - size) / 2

    color = @color_btn.rgba
    cr.set_source_rgb(color.red, color.green, color.blue)
    cr.rectangle(x, y, size, size)
    cr.fill

    if @toggle_btn.active?
      cr.set_source_rgb(1, 1, 1)
      cr.set_line_width(2)
      cr.rectangle(x - 10, y - 10, size + 20, size + 20)
      cr.stroke
    end
  end

  def draw_triangle(cr, width, height)
    center_x = width / 2
    center_y = height / 2
    size = [width, height].min / 4 * (@slider.value / 100.0)

    color = @color_btn.rgba
    cr.set_source_rgb(color.red, color.green, color.blue)
    cr.move_to(center_x, center_y - size)
    cr.line_to(center_x - size, center_y + size)
    cr.line_to(center_x + size, center_y + size)
    cr.close_path
    cr.fill
  end

  def draw_mouse_trail(cr)
    return if @mouse_trail.empty?

    # Dessiner le trail avec un dégradé de couleur
    @mouse_trail.each_with_index do |(x, y), index|
      alpha = index.to_f / @mouse_trail.size
      cr.set_source_rgba(0, 1, 0, alpha)
      cr.arc(x, y, 3, 0, 2 * Math::PI)
      cr.fill
    end

    # Relier les points
    cr.set_source_rgb(0, 1, 0)
    cr.set_line_width(2)

    @mouse_trail.each_cons(2) do |(x1, y1), (x2, y2)|
      cr.move_to(x1, y1)
      cr.line_to(x2, y2)
    end
    cr.stroke
  end

  def draw_particles(cr)
    update_particles

    @particles.each do |particle|
      cr.set_source_rgba(particle[:r], particle[:g], particle[:b], particle[:a])
      cr.arc(particle[:x], particle[:y], particle[:size], 0, 2 * Math::PI)
      cr.fill
    end
  end

  def update_particles
    if rand < 0.3
      color = @color_btn.rgba
      @particles << {
        x: rand(@canvas.allocated_width),
        y: rand(@canvas.allocated_height),
        dx: rand * 4 - 2,
        dy: rand * 4 - 2,
        size: rand * 5 + 2,
        r: color.red,
        g: color.green,
        b: color.blue,
        a: rand * 0.5 + 0.5
      }
    end

    @particles.reject! do |particle|
      particle[:x] += particle[:dx]
      particle[:y] += particle[:dy]
      particle[:a] -= 0.02

      particle[:x] < 0 || particle[:x] > @canvas.allocated_width ||
      particle[:y] < 0 || particle[:y] > @canvas.allocated_height ||
      particle[:a] <= 0
    end
  end

  def start_animation
    return if @animation_timeout

    @last_frame_time = Time.now.to_f
    @frame_count = 0

    @animation_timeout = GLib::Timeout.add(16) do
      if @toggle_btn.active?
        @animation_angle += 0.1
        @animation_angle %= (2 * Math::PI)

        current_time = Time.now.to_f
        @frame_count += 1

        if current_time - @last_frame_time >= 1.0
          fps = @frame_count.to_f / (current_time - @last_frame_time)
          @fps_label.text = "FPS: #{fps.round(1)}"
          @last_frame_time = current_time
          @frame_count = 0
        end

        @canvas.queue_draw
        true
      else
        @animation_timeout = nil
        false
      end
    end
  end

  def stop_animation
    if @animation_timeout
      GLib::Source.remove(@animation_timeout)
      @animation_timeout = nil
    end
  end

  def update_time
    current_time = Time.now.strftime("%H:%M:%S")
    @time_label.text = "Temps: #{current_time}"
  end

  def show_info_dialog
    dialog = Gtk::MessageDialog.new(:parent => @window,
                                   :flags => :modal,
                                   :type => :info,
                                   :buttons => :ok,
                                   :message => "Ruby/GTK3 Showcase\n\nUne démonstration complète des capacités de Ruby/GTK3\n\n• Canvas animé avec Cairo\n• Système de particules temps réel\n• Panneaux redimensionnables\n• Contrôles interactifs variés\n• Affichage de données structurées\n\nDéveloppé avec Ruby #{RUBY_VERSION}")
    dialog.run
    dialog.destroy
  end
end

# Lancement de l'application
if __FILE__ == $0
  puts "🚀 Lancement du showcase Ruby/GTK3..."
  puts "📋 Fonctionnalités démontrées:"
  puts "   ✓ Fenêtre avec panneau redimensionnable"
  puts "   ✓ Canvas animé avec dessin Cairo"
  puts "   ✓ Système de particules temps réel"
  puts "   ✓ Contrôles interactifs variés"
  puts "   ✓ TreeView avec données structurées"
  puts "   ✓ Éditeur de texte avec code exemple"
  puts "   ✓ Animations et FPS en temps réel"
  puts "   ✓ Barre de status interactive"
  puts ""

  showcase = Gtk3Showcase.new
  showcase.show

  Gtk.main
end
