#!/usr/bin/env ruby
# frozen_string_literal: true

require 'gtk3'
require 'cmath'

class GraphWidget < Gtk::DrawingArea
  attr_accessor :x_min, :x_max, :y_min, :y_max, :show_grid, :show_axes, :functions,
                :origin_x, :origin_y

  def initialize
    super()

    # Configuration par défaut
    @x_min = -10.0
    @x_max = 10.0
    @y_min = -10.0
    @y_max = 10.0
    @origin_x = 0.0    # Position de l'origine en x
    @origin_y = 0.0    # Position de l'origine en y

    @show_grid = true
    @show_axes = true
    @functions = {}

    # Couleurs pour les courbes
    @colors = [
      [1.0, 0.2, 0.2],   # rouge
      [0.2, 0.6, 1.0],   # bleu
      [0.2, 0.8, 0.2],   # vert
      [0.8, 0.4, 0.0],   # orange
      [0.6, 0.2, 0.8]    # violet
    ]

    set_size_request(600, 400)
    signal_connect("draw") { |widget, cr| draw(cr) }
  end

  # Configuration simple des limites
  def set_limits(x_min:, x_max:, y_min:, y_max:)
    @x_min = x_min.to_f
    @x_max = x_max.to_f
    @y_min = y_min.to_f
    @y_max = y_max.to_f
    queue_draw
  end

  # Définition de l'origine
  def set_origin(x:, y:)
    @origin_x = x.to_f
    @origin_y = y.to_f
    queue_draw
  end

  # Ajout d'une fonction
  def add_function(name, &block)
    @functions[name] = block
    queue_draw
  end

  def remove_function(name)
    @functions.delete(name)
    queue_draw
  end

  def clear_functions
    @functions.clear
    queue_draw
  end

  private

  def draw(cr)
    width = allocation.width
    height = allocation.height

    # Fond blanc
    cr.set_source_rgb(1, 1, 1)
    cr.paint

    # Calcul des transformations
    scale_x = width / (@x_max - @x_min)
    scale_y = height / (@y_max - @y_min)

    # Translation pour positionner l'origine
    translate_x = -@x_min * scale_x
    translate_y = @y_max * scale_y

    cr.save do
      cr.translate(translate_x, translate_y)
      cr.scale(scale_x, -scale_y)

      # Grille et axes
      draw_grid(cr) if @show_grid
      draw_axes(cr) if @show_axes

      # Courbes
      draw_functions(cr)
    end

    # Cadre
    cr.set_source_rgb(0.8, 0.8, 0.8)
    cr.set_line_width(1)
    cr.rectangle(0, 0, width, height)
    cr.stroke
  end

  def draw_grid(cr)
    cr.set_source_rgba(0.9, 0.9, 0.9, 0.5)
    cr.set_line_width(0.002)

    # Lignes verticales
    (@x_min.ceil...@x_max).step(1) do |x|
      next if (x - @origin_x).abs < 0.001
      cr.move_to(x, @y_min)
      cr.line_to(x, @y_max)
      cr.stroke
    end

    # Lignes horizontales
    (@y_min.ceil...@y_max).step(1) do |y|
      next if (y - @origin_y).abs < 0.001
      cr.move_to(@x_min, y)
      cr.line_to(@x_max, y)
      cr.stroke
    end
  end

  def draw_axes(cr)
    cr.set_source_rgb(0, 0, 0)
    cr.set_line_width(0.005)

    # Axe X (à la position origin_y)
    cr.move_to(@x_min, @origin_y)
    cr.line_to(@x_max, @origin_y)
    cr.stroke

    # Axe Y (à la position origin_x)
    cr.move_to(@origin_x, @y_min)
    cr.line_to(@origin_x, @y_max)
    cr.stroke

    # Graduations
    cr.set_line_width(0.003)

    # Graduations sur l'axe X
    (@x_min.ceil...@x_max).step(1) do |x|
      cr.move_to(x, @origin_y - 0.1)
      cr.line_to(x, @origin_y + 0.1)
      cr.stroke
    end

    # Graduations sur l'axe Y
    (@y_min.ceil...@y_max).step(1) do |y|
      cr.move_to(@origin_x - 0.1, y)
      cr.line_to(@origin_x + 0.1, y)
      cr.stroke
    end
  end

  def draw_functions(cr)
    step = (@x_max - @x_min) / 1000.0
    color_index = 0

    @functions.each do |name, func|
      cr.set_source_rgb(*@colors[color_index % @colors.size])
      cr.set_line_width(0.008)

      begin
        first_point = true
        x = @x_min

        while x <= @x_max
          y = func.call(x)

          if y.is_a?(Numeric) && y.finite?
            if first_point
              cr.move_to(x, y)
              first_point = false
            else
              cr.line_to(x, y)
            end
          else
            first_point = true
          end

          x += step
        end

        cr.stroke
      rescue => e
        puts "Erreur: #{e.message}"
      end

      color_index += 1
    end
  end
end

# API simplifiée
class Graph
  def initialize
    @window = Gtk::Window.new(:toplevel)
    @window.set_title("Graphique")
    @window.set_default_size(800, 600)
    @window.signal_connect("destroy") { Gtk.main_quit }

    setup_ui
  end

  def setup_ui
    main_box = Gtk::Box.new(:horizontal, 0)

    @graph = GraphWidget.new
    main_box.pack_start(@graph, expand: true, fill: true, padding: 0)

    # Panneau de contrôle minimaliste
    control_panel = Gtk::Box.new(:vertical, 10)
    control_panel.set_margin_top(10)
    control_panel.set_margin_bottom(10)
    control_panel.set_margin_start(10)
    control_panel.set_margin_end(10)

    # Configuration des limites
    limits_frame = Gtk::Frame.new("Limites")
    limits_box = Gtk::Box.new(:vertical, 5)
    limits_frame.add(limits_box)

    grid = Gtk::Grid.new
    grid.set_column_spacing(5)
    grid.set_row_spacing(5)

    labels = ["X min:", "X max:", "Y min:", "Y max:"]
    @entries = []

    labels.each_with_index do |label, i|
      grid.attach(Gtk::Label.new(label), 0, i, 1, 1)
      entry = Gtk::Entry.new
      entry.set_width_chars(8)
      grid.attach(entry, 1, i, 1, 1)
      @entries << entry
    end

    # Valeurs par défaut
    @entries[0].text = @graph.x_min.to_s
    @entries[1].text = @graph.x_max.to_s
    @entries[2].text = @graph.y_min.to_s
    @entries[3].text = @graph.y_max.to_s

    limits_box.pack_start(grid, expand: false, fill: false, padding: 5)

    apply_btn = Gtk::Button.new(label: "Appliquer")
    apply_btn.signal_connect("clicked") { apply_limits }
    limits_box.pack_start(apply_btn, expand: false, fill: false, padding: 5)

    control_panel.pack_start(limits_frame, expand: false, fill: false, padding: 5)

    # Origine
    origin_frame = Gtk::Frame.new("Origine (0,0)")
    origin_box = Gtk::Box.new(:vertical, 5)
    origin_frame.add(origin_box)

    origin_grid = Gtk::Grid.new
    origin_grid.set_column_spacing(5)

    origin_grid.attach(Gtk::Label.new("X:"), 0, 0, 1, 1)
    @origin_x_entry = Gtk::Entry.new
    @origin_x_entry.text = "0"
    @origin_x_entry.set_width_chars(8)
    origin_grid.attach(@origin_x_entry, 1, 0, 1, 1)

    origin_grid.attach(Gtk::Label.new("Y:"), 0, 1, 1, 1)
    @origin_y_entry = Gtk::Entry.new
    @origin_y_entry.text = "0"
    @origin_y_entry.set_width_chars(8)
    origin_grid.attach(@origin_y_entry, 1, 1, 1, 1)

    origin_box.pack_start(origin_grid, expand: false, fill: false, padding: 5)

    center_btn = Gtk::Button.new(label: "Centrer")
    center_btn.signal_connect("clicked") { center_origin }
    origin_box.pack_start(center_btn, expand: false, fill: false, padding: 5)

    control_panel.pack_start(origin_frame, expand: false, fill: false, padding: 5)

    # Affichage
    display_frame = Gtk::Frame.new("Affichage")
    display_box = Gtk::Box.new(:vertical, 5)
    display_frame.add(display_box)

    @show_grid = Gtk::CheckButton.new("Grille")
    @show_grid.active = true
    @show_grid.signal_connect("toggled") { @graph.show_grid = @show_grid.active?; @graph.queue_draw }
    display_box.pack_start(@show_grid, expand: false, fill: false, padding: 5)

    @show_axes = Gtk::CheckButton.new("Axes")
    @show_axes.active = true
    @show_axes.signal_connect("toggled") { @graph.show_axes = @show_axes.active?; @graph.queue_draw }
    display_box.pack_start(@show_axes, expand: false, fill: false, padding: 5)

    control_panel.pack_start(display_frame, expand: false, fill: false, padding: 5)

    # Fonctions
    func_frame = Gtk::Frame.new("Fonctions")
    func_box = Gtk::Box.new(:vertical, 5)
    func_frame.add(func_box)

    @func_entry = Gtk::Entry.new
    @func_entry.placeholder_text = "->(x) { x**2 }"
    func_box.pack_start(@func_entry, expand: false, fill: false, padding: 5)

    add_btn = Gtk::Button.new(label: "Ajouter")
    add_btn.signal_connect("clicked") { add_function }
    func_box.pack_start(add_btn, expand: false, fill: false, padding: 5)

    clear_btn = Gtk::Button.new(label: "Effacer tout")
    clear_btn.signal_connect("clicked") { @graph.clear_functions }
    func_box.pack_start(clear_btn, expand: false, fill: false, padding: 5)

    control_panel.pack_start(func_frame, expand: false, fill: false, padding: 5)

    main_box.pack_end(control_panel, expand: false, fill: false, padding: 0)
    @window.add(main_box)
  end

  def apply_limits
    begin
      x_min = @entries[0].text.to_f
      x_max = @entries[1].text.to_f
      y_min = @entries[2].text.to_f
      y_max = @entries[3].text.to_f

      @graph.set_limits(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max)
    rescue => e
      puts "Erreur: #{e.message}"
    end
  end

  def center_origin
    begin
      x = @origin_x_entry.text.to_f
      y = @origin_y_entry.text.to_f
      @graph.set_origin(x: x, y: y)
    rescue => e
      puts "Erreur: #{e.message}"
    end
  end

  def add_function
    func_str = @func_entry.text.strip
    return if func_str.empty?

    begin
      func = eval(func_str)
      if func.is_a?(Proc)
        name = "f#{@graph.functions.size + 1}"
        @graph.add_function(name, &func)
        @func_entry.text = ""
      end
    rescue => e
      puts "Erreur: #{e.message}"
    end
  end

  # API publique
  def set_limits(x_min:, x_max:, y_min:, y_max:)
    @graph.set_limits(x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max)
    self
  end

  def set_origin(x:, y:)
    @graph.set_origin(x: x, y: y)
    self
  end

  def plot(name = "f", &block)
    @graph.add_function(name, &block)
    self
  end

  def show
    @window.show_all
    Gtk.main
  end
end

# API ultra simple
def create_graph
  Graph.new
end

# Exemple d'utilisation minimal
if __FILE__ == $0
  # Exemple 1: Configuration basique
  graph = create_graph
    .set_limits(x_min: -5, x_max: 5, y_min: -3, y_max: 3)
    .set_origin(x: 0, y: 0)
    .plot("sin") { |x| Math.sin(x) }
    .plot("x²") { |x| x**2 }

  # Exemple 2: Avec origine décalée
  # graph = create_graph
  #   .set_limits(x_min: 0, x_max: 20, y_min: -10, y_max: 10)
  #   .set_origin(x: 10, y: 0)  # Origine au centre horizontal
  #   .plot("line") { |x| 0.5 * x - 5 }

  graph.show
end
