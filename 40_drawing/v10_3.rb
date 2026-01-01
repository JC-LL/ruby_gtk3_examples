#!/usr/bin/env ruby
# frozen_string_literal: true

require 'gtk3'

class GraphWidget < Gtk::DrawingArea
  attr_accessor :x_min, :x_max, :y_min, :y_max, :show_grid, :show_axes, :functions

  def initialize
    super()

    # Configuration par défaut
    @x_min = -10.0
    @x_max = 10.0
    @y_min = -10.0
    @y_max = 10.0

    @show_grid = true
    @show_axes = true
    @functions = {}

    set_size_request(600, 400)
    signal_connect("draw") { |widget, cr| draw(cr) }
  end

  def set_view(x_min:, x_max:, y_min:, y_max:)
    @x_min = x_min
    @x_max = x_max
    @y_min = y_min
    @y_max = y_max
    queue_draw
  end

  def add_function(name, &block)
    @functions[name] = block
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

    # Calculs
    scale_x = width / (@x_max - @x_min)
    scale_y = height / (@y_max - @y_min)
    translate_x = -@x_min * scale_x
    translate_y = @y_max * scale_y

    cr.save do
      cr.translate(translate_x, translate_y)
      cr.scale(scale_x, -scale_y)

      # Grille simple
      draw_grid(cr) if @show_grid

      # Axes simples
      draw_axes(cr) if @show_axes

      # Courbes
      draw_functions(cr)
    end
  end

  def draw_grid(cr)
    cr.set_source_rgba(0.9, 0.9, 0.9, 0.5)
    cr.set_line_width(0.002)

    # Lignes verticales
    (@x_min.ceil...@x_max).step(1) do |x|
      cr.move_to(x, @y_min)
      cr.line_to(x, @y_max)
      cr.stroke
    end

    # Lignes horizontales
    (@y_min.ceil...@y_max).step(1) do |y|
      cr.move_to(@x_min, y)
      cr.line_to(@x_max, y)
      cr.stroke
    end
  end

  def draw_axes(cr)
    cr.set_source_rgb(0, 0, 0)
    cr.set_line_width(0.005)

    # Axe X
    cr.move_to(@x_min, 0)
    cr.line_to(@x_max, 0)
    cr.stroke

    # Axe Y
    cr.move_to(0, @y_min)
    cr.line_to(0, @y_max)
    cr.stroke

    # Graduations
    cr.set_line_width(0.003)

    # Sur l'axe X
    (@x_min.ceil...@x_max).step(1) do |x|
      cr.move_to(x, -0.1)
      cr.line_to(x, 0.1)
      cr.stroke
    end

    # Sur l'axe Y
    (@y_min.ceil...@y_max).step(1) do |y|
      cr.move_to(-0.1, y)
      cr.line_to(0.1, y)
      cr.stroke
    end
  end

  def draw_functions(cr)
    step = (@x_max - @x_min) / 1000.0

    @functions.each do |name, func|
      # Couleurs simples
      cr.set_source_rgb(rand, rand, rand)
      cr.set_line_width(0.01)

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
        puts "Erreur avec #{name}: #{e.message}"
      end
    end
  end
end

class GraphApp
  def initialize
    @window = Gtk::Window.new(:toplevel)
    @window.set_title("Traceur Simple")
    @window.set_default_size(800, 600)
    @window.signal_connect("destroy") { Gtk.main_quit }

    setup_ui
  end

  def setup_ui
    main_box = Gtk::Box.new(:horizontal, 0)

    @graph = GraphWidget.new
    main_box.pack_start(@graph, expand: true, fill: true, padding: 0)

    # Panneau de contrôle simple
    control_panel = Gtk::Box.new(:vertical, 10)
    control_panel.set_margin_top(10)
    control_panel.set_margin_bottom(10)
    control_panel.set_margin_start(10)
    control_panel.set_margin_end(10)

    # Titre
    label = Gtk::Label.new("Contrôles")
    control_panel.pack_start(label, expand: false, fill: false, padding: 5)

    # Affichage
    @show_grid = Gtk::CheckButton.new("Grille")
    @show_grid.active = true
    @show_grid.signal_connect("toggled") { @graph.show_grid = @show_grid.active?; @graph.queue_draw }
    control_panel.pack_start(@show_grid, expand: false, fill: false, padding: 5)

    @show_axes = Gtk::CheckButton.new("Axes")
    @show_axes.active = true
    @show_axes.signal_connect("toggled") { @graph.show_axes = @show_axes.active?; @graph.queue_draw }
    control_panel.pack_start(@show_axes, expand: false, fill: false, padding: 5)

    # Saisie de fonction
    func_frame = Gtk::Frame.new("Fonction")
    func_box = Gtk::Box.new(:vertical, 5)
    func_frame.add(func_box)

    @func_entry = Gtk::Entry.new
    @func_entry.placeholder_text = "->(x) { x**2 }"
    func_box.pack_start(@func_entry, expand: false, fill: false, padding: 5)

    add_btn = Gtk::Button.new(label: "Ajouter")
    add_btn.signal_connect("clicked") { add_function }
    func_box.pack_start(add_btn, expand: false, fill: false, padding: 5)

    clear_btn = Gtk::Button.new(label: "Tout effacer")
    clear_btn.signal_connect("clicked") { @graph.clear_functions }
    func_box.pack_start(clear_btn, expand: false, fill: false, padding: 5)

    control_panel.pack_start(func_frame, expand: false, fill: false, padding: 5)

    main_box.pack_end(control_panel, expand: false, fill: false, padding: 0)
    @window.add(main_box)

    # Ajouter quelques fonctions par défaut
    @graph.add_function("x²") { |x| x**2 }
    @graph.add_function("sin(x)") { |x| Math.sin(x) }
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

  def run
    @window.show_all
    Gtk.main
  end
end

# Lancement simple
if __FILE__ == $0
  puts "Lancement du traceur simple..."
  app = GraphApp.new
  app.run
end
