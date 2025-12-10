#!/usr/bin/env ruby
# encoding: utf-8

require 'gtk3'

class SimulationGUI < Gtk::Window
  def initialize
    super

    # Configuration de la fenêtre principale
    set_title("Simulation")
    set_default_size(1400, 800)
    set_border_width(5)

    # Style CSS pour les boutons
    css_provider = Gtk::CssProvider.new
    css_provider.load(data: <<-CSS)
      button {
        border-radius: 4px;
        padding: 8px;
        border: 1px solid #555;
        background: linear-gradient(to bottom, #444, #333);
        color: #eee;
      }
      button:hover {
        background: linear-gradient(to bottom, #555, #444);
      }
      button:active {
        background: linear-gradient(to bottom, #333, #444);
      }
      button:disabled {
        background: #222;
        color: #666;
        border-color: #333;
      }
    CSS

    screen = Gdk::Screen.default
    Gtk::StyleContext.add_provider_for_screen(screen, css_provider, Gtk::StyleProvider::PRIORITY_USER)

    # Conteneur principal horizontal
    main_box = Gtk::Box.new(:horizontal, 10)
    add(main_box)

    # Partie gauche : Deux canvas côte à côte
    canvas_container = Gtk::Box.new(:horizontal, 10)
    canvas_container.set_hexpand(true)
    canvas_container.set_vexpand(true)
    main_box.pack_start(canvas_container, expand: true, fill: true, padding: 0)

    # Canvas gauche
    @left_canvas = Gtk::DrawingArea.new
    @left_canvas.set_hexpand(true)
    @left_canvas.set_vexpand(true)
    @left_canvas.set_size_request(600, -1)
    canvas_container.pack_start(@left_canvas, expand: true, fill: true, padding: 0)

    # Canvas droit
    @right_canvas = Gtk::DrawingArea.new
    @right_canvas.set_hexpand(true)
    @right_canvas.set_vexpand(true)
    @right_canvas.set_size_request(600, -1)
    canvas_container.pack_start(@right_canvas, expand: true, fill: true, padding: 0)

    # Connecter les signaux de dessin
    @left_canvas.signal_connect("draw") do |widget, context|
      draw_canvas(context, widget.allocated_width, widget.allocated_height, "CANVAS 1", true)
    end

    @right_canvas.signal_connect("draw") do |widget, context|
      draw_canvas(context, widget.allocated_width, widget.allocated_height, "CANVAS 2", false)
    end

    # Partie droite : Panneau de contrôle vertical
    right_panel = Gtk::Box.new(:vertical, 15)
    right_panel.set_size_request(120, -1)
    right_panel.set_margin_start(10)
    right_panel.set_margin_top(20)
    main_box.pack_start(right_panel, expand: false, fill: true, padding: 0)

    # Bouton Démarrer
    @start_button = Gtk::Button.new
    start_icon = Gtk::Image.new(icon_name: "media-playback-start", size: :large_toolbar)
    @start_button.add(start_icon)
    @start_button.set_tooltip_text("Démarrer la simulation")
    @start_button.signal_connect("clicked") { start_simulation }
    @start_button.set_size_request(60, 60)
    right_panel.pack_start(@start_button, expand: false, fill: false, padding: 0)

    # Bouton Arrêter
    @stop_button = Gtk::Button.new
    stop_icon = Gtk::Image.new(icon_name: "media-playback-pause", size: :large_toolbar)
    @stop_button.add(stop_icon)
    @stop_button.set_tooltip_text("Arrêter la simulation")
    @stop_button.sensitive = false
    @stop_button.signal_connect("clicked") { stop_simulation }
    @stop_button.set_size_request(60, 60)
    right_panel.pack_start(@stop_button, expand: false, fill: false, padding: 0)

    # Bouton Étape
    @step_button = Gtk::Button.new
    step_icon = Gtk::Image.new(icon_name: "go-next", size: :large_toolbar)
    @step_button.add(step_icon)
    @step_button.set_tooltip_text("Avancer d'une étape")
    @step_button.signal_connect("clicked") { step_simulation }
    @step_button.set_size_request(60, 60)
    right_panel.pack_start(@step_button, expand: false, fill: false, padding: 0)

    # Bouton Réinitialiser
    @reset_button = Gtk::Button.new
    reset_icon = Gtk::Image.new(icon_name: "view-refresh", size: :large_toolbar)
    @reset_button.add(reset_icon)
    @reset_button.set_tooltip_text("Réinitialiser la simulation")
    @reset_button.signal_connect("clicked") { reset_simulation }
    @reset_button.set_size_request(60, 60)
    right_panel.pack_start(@reset_button, expand: false, fill: false, padding: 0)

    # Séparateur
    separator = Gtk::Separator.new(:horizontal)
    separator.set_margin_top(20)
    separator.set_margin_bottom(20)
    right_panel.pack_start(separator, expand: false, fill: false, padding: 0)

    # Contrôle de vitesse
    speed_box = Gtk::Box.new(:vertical, 5)
    right_panel.pack_start(speed_box, expand: false, fill: false, padding: 0)

    speed_icon = Gtk::Image.new(icon_name: "preferences-system-time", size: :large_toolbar)
    speed_box.pack_start(speed_icon, expand: false, fill: false, padding: 0)

    @speed_slider = Gtk::Scale.new(:vertical, 0.1, 10.0, 0.1)
    @speed_slider.set_inverted(true)  # Haut = rapide, bas = lent
    @speed_slider.set_value(1.0)
    @speed_slider.set_draw_value(false)
    @speed_slider.set_size_request(40, 200)
    @speed_slider.signal_connect("value-changed") do |scale|
      update_speed(scale.value)
    end
    speed_box.pack_start(@speed_slider, expand: false, fill: false, padding: 0)

    @speed_value_label = Gtk::Label.new("1.0")
    @speed_value_label.set_markup("<span size='small'>1.0</span>")
    speed_box.pack_start(@speed_value_label, expand: false, fill: false, padding: 0)

    # Indicateur d'état discret
    @status_indicator = Gtk::DrawingArea.new
    @status_indicator.set_size_request(20, 20)
    @status_indicator.signal_connect("draw") do |widget, context|
      draw_status_indicator(context, widget.allocated_width, widget.allocated_height)
    end
    @status_indicator.set_tooltip_text("État: Arrêté")
    right_panel.pack_start(@status_indicator, expand: false, fill: false, padding: 0)

    # Variables de simulation
    @simulation_running = false
    @simulation_step = 0
    @simulation_speed = 1.0
    @timeout_id = nil

    # Gestion de la fermeture
    signal_connect("destroy") do
      stop_simulation if @simulation_running
      Gtk.main_quit
    end

    # Redimensionnement automatique
    signal_connect("configure-event") do
      @left_canvas.queue_draw
      @right_canvas.queue_draw
    end
  end

  def draw_canvas(context, width, height, title, is_left)
    # Fond bleu nuit
    context.set_source_rgb(0.047, 0.078, 0.149)  # Bleu nuit profond
    context.rectangle(0, 0, width, height)
    context.fill

    # Dessiner la grille (premier quadrant uniquement)
    draw_grid(context, width, height)

    # Cadre autour du canvas
    context.set_source_rgb(0.2, 0.4, 0.8)  # Bleu clair
    context.set_line_width(1.5)
    context.rectangle(1, 1, width - 2, height - 2)
    context.stroke

    # Titre discret du canvas
    context.set_source_rgb(0.7, 0.7, 0.9)  # Gris bleuté clair
    context.select_font_face("Sans", Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_NORMAL)
    context.set_font_size(14)

    text_extents = context.text_extents(title)
    x = (width - text_extents.width) / 2
    y = 25

    context.move_to(x, y)
    context.show_text(title)

    # Indicateur de pas de simulation (discret)
    context.set_font_size(12)
    step_text = "Step: #{@simulation_step}"
    step_extents = context.text_extents(step_text)
    step_x = width - step_extents.width - 15
    step_y = height - 15

    context.move_to(step_x, step_y)
    context.show_text(step_text)

    # Indicateur de vitesse (discret)
    context.set_font_size(11)
    speed_text = "Speed: #{@simulation_speed.round(1)}x"
    speed_extents = context.text_extents(speed_text)
    speed_x = 15
    speed_y = height - 15

    context.move_to(speed_x, speed_y)
    context.show_text(speed_text)

    # Origine des axes (coin inférieur gauche)
    context.set_source_rgba(1, 1, 1, 0.8)
    context.set_font_size(10)
    context.move_to(10, height - 25)
    context.show_text("(0,0)")

    # Si simulation en cours, dessiner un indicateur discret
    if @simulation_running
      draw_simulation_indicator(context, width, height, is_left)
    end
  end

  def draw_grid(context, width, height)
    # Marge pour les axes et labels
    margin_left = 40
    margin_bottom = 40
    margin_top = 30
    margin_right = 20

    grid_width = width - margin_left - margin_right
    grid_height = height - margin_top - margin_bottom

    # Origine en bas à gauche
    origin_x = margin_left
    origin_y = height - margin_bottom

    # Dessiner le fond du quadrant
    context.set_source_rgba(0.1, 0.15, 0.25, 0.5)
    context.rectangle(origin_x, margin_top, grid_width, grid_height)
    context.fill

    # Grille principale (tous les 50 pixels)
    context.set_source_rgba(0.3, 0.5, 0.8, 0.25)
    context.set_line_width(1.0)

    # Lignes verticales (x ≥ 0)
    (0..grid_width).step(50).each do |x_offset|
      x = origin_x + x_offset
      context.move_to(x, margin_top)
      context.line_to(x, origin_y)
      context.stroke
    end

    # Lignes horizontales (y ≥ 0)
    (0..grid_height).step(50).each do |y_offset|
      y = origin_y - y_offset
      context.move_to(origin_x, y)
      context.line_to(origin_x + grid_width, y)
      context.stroke
    end

    # Grille secondaire (tous les 10 pixels) - plus fine
    context.set_source_rgba(0.4, 0.6, 0.9, 0.1)
    context.set_line_width(0.5)

    # Lignes verticales secondaires
    (0..grid_width).step(10).each do |x_offset|
      next if x_offset % 50 == 0  # Éviter de redessiner les lignes principales
      x = origin_x + x_offset
      context.move_to(x, margin_top)
      context.line_to(x, origin_y)
      context.stroke
    end

    # Lignes horizontales secondaires
    (0..grid_height).step(10).each do |y_offset|
      next if y_offset % 50 == 0  # Éviter de redessiner les lignes principales
      y = origin_y - y_offset
      context.move_to(origin_x, y)
      context.line_to(origin_x + grid_width, y)
      context.stroke
    end

    # Axes x et y
    context.set_source_rgba(1, 1, 1, 0.7)
    context.set_line_width(1.5)

    # Axe des x (horizontal, y=0)
    context.move_to(origin_x, origin_y)
    context.line_to(origin_x + grid_width, origin_y)
    context.stroke

    # Axe des y (vertical, x=0)
    context.move_to(origin_x, origin_y)
    context.line_to(origin_x, margin_top)
    context.stroke

    # Flèches sur les axes
    context.set_line_width(1.0)

    # Flèche axe des x
    context.move_to(origin_x + grid_width - 10, origin_y - 5)
    context.line_to(origin_x + grid_width, origin_y)
    context.line_to(origin_x + grid_width - 10, origin_y + 5)
    context.stroke

    # Flèche axe des y
    context.move_to(origin_x - 5, margin_top + 10)
    context.line_to(origin_x, margin_top)
    context.line_to(origin_x + 5, margin_top + 10)
    context.stroke

    # Labels des axes
    context.set_source_rgba(1, 1, 1, 0.9)
    context.set_font_size(12)

    # Label axe des x
    x_label = "x"
    x_extents = context.text_extents(x_label)
    context.move_to(origin_x + grid_width - x_extents.width - 5, origin_y - 10)
    context.show_text(x_label)

    # Label axe des y
    y_label = "y"
    y_extents = context.text_extents(y_label)
    context.move_to(origin_x + 10, margin_top + y_extents.height + 5)
    context.show_text(y_label)

    # Graduations et labels numériques
    context.set_font_size(10)

    # Graduations sur l'axe des x
    (0..grid_width).step(50).each do |x_offset|
      next if x_offset == 0
      x = origin_x + x_offset
      value = (x_offset / 10).to_i  # Échelle: 10 pixels = 1 unité

      # Petite ligne de graduation
      context.set_line_width(1.0)
      context.move_to(x, origin_y - 3)
      context.line_to(x, origin_y + 3)
      context.stroke

      # Label numérique
      text = value.to_s
      text_extents = context.text_extents(text)
      context.move_to(x - text_extents.width / 2, origin_y + 15)
      context.show_text(text)
    end

    # Graduations sur l'axe des y
    (0..grid_height).step(50).each do |y_offset|
      next if y_offset == 0
      y = origin_y - y_offset
      value = (y_offset / 10).to_i  # Échelle: 10 pixels = 1 unité

      # Petite ligne de graduation
      context.set_line_width(1.0)
      context.move_to(origin_x - 3, y)
      context.line_to(origin_x + 3, y)
      context.stroke

      # Label numérique
      text = value.to_s
      text_extents = context.text_extents(text)
      context.move_to(origin_x - text_extents.width - 8, y + text_extents.height / 2)
      context.show_text(text)
    end
  end

  def draw_simulation_indicator(context, width, height, is_left)
    # Animation subtile de points
    time = Time.now.to_f * 2

    # Points discrets qui se déplacent selon une trajectoire
    15.times do |i|
      phase = time + i * Math::PI / 7.5

      # Position dans le quadrant (x≥0, y≥0)
      margin_left = 40
      margin_bottom = 40
      margin_top = 30
      grid_height = height - margin_top - margin_bottom

      x = margin_left + (Math.cos(phase * 0.7).abs * (width - margin_left - 50)).to_i
      y = height - margin_bottom - (Math.sin(phase * 1.2).abs * grid_height).to_i

      # Couleur différente pour chaque canvas
      if is_left
        context.set_source_rgba(0.2, 0.8, 0.4, 0.6)  # Vert discret
      else
        context.set_source_rgba(0.8, 0.4, 0.2, 0.6)  # Orange discret
      end

      radius = 2 + Math.sin(phase) * 1
      context.arc(x, y, radius, 0, 2 * Math::PI)
      context.fill
    end
  end

  def draw_status_indicator(context, width, height)
    # Indicateur circulaire d'état
    if @simulation_running
      context.set_source_rgb(0, 0.8, 0)  # Vert
    else
      context.set_source_rgb(0.8, 0, 0)  # Rouge
    end

    radius = [width, height].min / 2 - 2
    context.arc(width / 2, height / 2, radius, 0, 2 * Math::PI)
    context.fill

    # Contour
    context.set_source_rgb(0.3, 0.3, 0.3)
    context.set_line_width(1)
    context.arc(width / 2, height / 2, radius, 0, 2 * Math::PI)
    context.stroke
  end

  def start_simulation
    return if @simulation_running

    @simulation_running = true
    @start_button.sensitive = false
    @stop_button.sensitive = true
    @step_button.sensitive = false
    @status_indicator.set_tooltip_text("État: En cours")
    @status_indicator.queue_draw

    # Démarrer la boucle d'animation
    @timeout_id = GLib::Timeout.add((100 / @simulation_speed).to_i) do
      if @simulation_running
        @simulation_step += 1

        # Mettre à jour l'affichage des canvas
        @left_canvas.queue_draw
        @right_canvas.queue_draw

        true  # Continuer le timeout
      else
        false  # Arrêter le timeout
      end
    end
  end

  def stop_simulation
    return unless @simulation_running

    @simulation_running = false
    @start_button.sensitive = true
    @stop_button.sensitive = false
    @step_button.sensitive = true
    @status_indicator.set_tooltip_text("État: Arrêté")
    @status_indicator.queue_draw

    # Nettoyer le timeout si existant
    if @timeout_id
      GLib::Source.remove(@timeout_id)
      @timeout_id = nil
    end

    # Mettre à jour l'affichage
    @left_canvas.queue_draw
    @right_canvas.queue_draw
  end

  def step_simulation
    @simulation_step += 1
    @left_canvas.queue_draw
    @right_canvas.queue_draw
  end

  def reset_simulation
    stop_simulation
    @simulation_step = 0
    @speed_slider.set_value(1.0)
    @speed_value_label.set_markup("<span size='small'>1.0</span>")
    @status_indicator.set_tooltip_text("État: Réinitialisé")
    @status_indicator.queue_draw
    @left_canvas.queue_draw
    @right_canvas.queue_draw

    # Revenir à "Arrêté" après 1 seconde
    GLib::Timeout.add(1000) do
      @status_indicator.set_tooltip_text("État: Arrêté")
      @status_indicator.queue_draw
      false
    end
  end

  def update_speed(value)
    @simulation_speed = value
    @speed_value_label.set_markup("<span size='small'>#{value.round(1)}</span>")

    # Si la simulation est en cours, redémarrer le timeout avec la nouvelle vitesse
    if @simulation_running
      stop_simulation
      start_simulation
    end

    # Mettre à jour l'affichage
    @left_canvas.queue_draw
    @right_canvas.queue_draw
  end
end

# Vérifier si GTK est disponible
begin
  # Lancer l'application
  app = SimulationGUI.new
  app.show_all

  # Centrer la fenêtre
  app.set_window_position(:center_always)

  Gtk.main
rescue LoadError => e
  puts "Erreur: Impossible de charger GTK3"
  puts "Installez la gem avec: gem install gtk3"
  puts "Assurez-vous que GTK3 est installé sur votre système"
  exit 1
end
