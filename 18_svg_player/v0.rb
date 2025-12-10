#!/usr/bin/env ruby
# encoding: utf-8

require 'gtk3'
require 'fileutils'

class SVGAnimationPlayer
  def initialize
    @current_frame = 0
    @frames = []
    @playing = false
    @loop = false
    @delay = 100  # ms entre les frames
    @timer_id = nil
    @directory = nil
    @file_pattern = nil

    build_ui
    setup_signals
  end

  def build_ui
    # Fenêtre principale
    @window = Gtk::Window.new("Lecteur d'Animation SVG")
    @window.set_default_size(800, 600)
    @window.resizable = true
    @window.signal_connect("destroy") { Gtk.main_quit }

    # Conteneur principal
    @main_box = Gtk::Box.new(:horizontal, 5)
    @window.add(@main_box)

    # Zone d'affichage SVG
    @scrolled_window = Gtk::ScrolledWindow.new
    @scrolled_window.set_policy(:automatic, :automatic)
    @main_box.pack_start(@scrolled_window, expand: true, fill: true, padding: 0)

    @drawing_area = Gtk::DrawingArea.new
    @drawing_area.set_hexpand(true)
    @drawing_area.set_vexpand(true)
    @scrolled_window.add(@drawing_area)

    # Panneau de contrôle à droite
    @control_panel = Gtk::Box.new(:vertical, 5)
    @control_panel.margin = 10
    @control_panel.width_request = 200
    @main_box.pack_end(@control_panel, expand: false, fill: true, padding: 0)

    # Titre du panneau
    @title_label = Gtk::Label.new
    @title_label.markup = "<b>Contrôles</b>"
    @title_label.margin_bottom = 10
    @control_panel.pack_start(@title_label, expand: false, fill: false, padding: 0)

    # Bouton pour charger les images
    @load_button = Gtk::Button.new(label: "Charger les images")
    @load_button.sensitive = true
    @control_panel.pack_start(@load_button, expand: false, fill: false, padding: 0)

    # Informations sur le chargement
    @info_label = Gtk::Label.new("Aucune image chargée")
    @info_label.wrap = true
    @control_panel.pack_start(@info_label, expand: false, fill: false, padding: 0)

    # Séparateur
    @control_panel.pack_start(Gtk::Separator.new(:horizontal), expand: false, fill: true, padding: 5)

    # Contrôles de lecture
    @play_button = Gtk::Button.new(label: "▶ Jouer")
    @play_button.sensitive = false
    @control_panel.pack_start(@play_button, expand: false, fill: false, padding: 0)

    @pause_button = Gtk::Button.new(label: "⏸ Pause")
    @pause_button.sensitive = false
    @control_panel.pack_start(@pause_button, expand: false, fill: false, padding: 0)

    @step_forward_button = Gtk::Button.new(label: "▶ Pas à pas")
    @step_forward_button.sensitive = false
    @control_panel.pack_start(@step_forward_button, expand: false, fill: false, padding: 0)

    @step_backward_button = Gtk::Button.new(label: "◀ Pas à pas")
    @step_backward_button.sensitive = false
    @control_panel.pack_start(@step_backward_button, expand: false, fill: false, padding: 0)

    # Contrôles de vitesse
    @speed_box = Gtk::Box.new(:horizontal, 5)
    @control_panel.pack_start(@speed_box, expand: false, fill: false, padding: 0)

    @slow_button = Gtk::Button.new(label: "Ralentir")
    @slow_button.sensitive = false
    @speed_box.pack_start(@slow_button, expand: false, fill: false, padding: 0)

    @fast_button = Gtk::Button.new(label: "Accélérer")
    @fast_button.sensitive = false
    @speed_box.pack_start(@fast_button, expand: false, fill: false, padding: 0)

    # Affichage de la vitesse
    @speed_label = Gtk::Label.new("Vitesse: #{@delay}ms/image")
    @control_panel.pack_start(@speed_label, expand: false, fill: false, padding: 0)

    # Contrôle de boucle
    @loop_check = Gtk::CheckButton.new("Lecture en boucle")
    @loop_check.active = @loop
    @control_panel.pack_start(@loop_check, expand: false, fill: false, padding: 0)

    # Séparateur
    @control_panel.pack_start(Gtk::Separator.new(:horizontal), expand: false, fill: true, padding: 5)

    # Informations sur la frame courante
    @frame_label = Gtk::Label.new("Frame: 0/0")
    @control_panel.pack_start(@frame_label, expand: false, fill: false, padding: 0)

    # Barre de défilement pour les frames - initialisée avec des valeurs valides
    @frame_scale = Gtk::Scale.new(:horizontal, 0, 100, 1)
    @frame_scale.sensitive = false
    @frame_scale.draw_value = false
    @control_panel.pack_start(@frame_scale, expand: false, fill: true, padding: 0)

    # Bouton de réinitialisation
    @reset_button = Gtk::Button.new(label: "Réinitialiser")
    @reset_button.sensitive = false
    @control_panel.pack_start(@reset_button, expand: false, fill: false, padding: 0)
  end

  def setup_signals
    @drawing_area.signal_connect("draw") { |widget, context| draw_svg(widget, context) }

    @load_button.signal_connect("clicked") { load_images }
    @play_button.signal_connect("clicked") { play_animation }
    @pause_button.signal_connect("clicked") { pause_animation }
    @step_forward_button.signal_connect("clicked") { step_forward }
    @step_backward_button.signal_connect("clicked") { step_backward }
    @slow_button.signal_connect("clicked") { adjust_speed(-20) }
    @fast_button.signal_connect("clicked") { adjust_speed(20) }
    @loop_check.signal_connect("toggled") { @loop = @loop_check.active? }
    @reset_button.signal_connect("clicked") { reset_animation }
    @frame_scale.signal_connect("value-changed") { change_frame_by_scale }

    # Redimensionnement de la fenêtre
    @drawing_area.signal_connect("configure-event") do
      @drawing_area.queue_draw
      false
    end
  end

  def load_images
    # Création d'un dialogue pour sélectionner le dossier
    dialog = Gtk::FileChooserDialog.new(
      title: "Sélectionner le dossier des images SVG",
      parent: @window,
      action: :select_folder
    )

    dialog.add_button("Annuler", Gtk::ResponseType::CANCEL)
    dialog.add_button("Ouvrir", Gtk::ResponseType::ACCEPT)

    if dialog.run == Gtk::ResponseType::ACCEPT
      @directory = dialog.filename
      load_svg_files
    end

    dialog.destroy
  end

  def load_svg_files
    return unless @directory && Dir.exist?(@directory)

    # Recherche des fichiers SVG avec un numéro suffixé
    @frames = Dir.glob(File.join(@directory, "*.svg"))
                .select { |f| f =~ /(\d+)\.svg$/i }
                .sort_by { |f| f.scan(/(\d+)\.svg$/i).first.first.to_i }

    if @frames.empty?
      @info_label.text = "Aucun fichier SVG trouvé avec format: nom_numero.svg"
      disable_controls
      @frame_label.text = "Frame: 0/0"
      @frame_scale.set_range(0, 1)  # Évite min = max
      @frame_scale.sensitive = false
    else
      @current_frame = 0
      @info_label.text = "Chargé: #{@frames.size} images\nDossier: #{File.basename(@directory)}"
      @frame_label.text = "Frame: #{@current_frame + 1}/#{@frames.size}"

      # Définir la plage uniquement si nous avons des frames
      if @frames.size > 1
        @frame_scale.set_range(0, @frames.size - 1)
      else
        @frame_scale.set_range(0, 1)  # Au moins 2 valeurs différentes
      end

      @frame_scale.set_value(@current_frame)
      @frame_scale.sensitive = true
      enable_controls
      @drawing_area.queue_draw
    end
  end

  def draw_svg(widget, context)
    return unless @frames && !@frames.empty? && @current_frame < @frames.size

    svg_file = @frames[@current_frame]
    return unless File.exist?(svg_file)

    # Dimensions de la zone de dessin
    allocation = widget.allocation
    width = allocation.width
    height = allocation.height

    # Lecture du SVG
    begin
      svg_content = File.read(svg_file)

      # Recherche des dimensions dans le SVG
      svg_width = svg_content[/width="([^"]+)"/, 1] || "100"
      svg_height = svg_content[/height="([^"]+)"/, 1] || "100"

      # Conversion des dimensions (suppression des unités)
      svg_width = svg_width.to_f
      svg_height = svg_height.to_f

      # Calcul du ratio pour le redimensionnement
      ratio = [width / svg_width, height / svg_height].min
      new_width = svg_width * ratio
      new_height = svg_height * ratio

      # Centrage de l'image
      x = (width - new_width) / 2
      y = (height - new_height) / 2

      # Chargement et rendu du SVG avec Cairo
      begin
        require 'rsvg2'

        handle = Rsvg::Handle.new_from_file(svg_file)
        context.save do
          context.translate(x, y)
          context.scale(ratio, ratio)
          context.render_rsvg_handle(handle)
        end
      rescue LoadError
        # Fallback: dessin d'un rectangle avec le nom du fichier
        context.set_source_rgb(0.9, 0.9, 0.9)
        context.rectangle(x, y, new_width, new_height)
        context.fill

        context.set_source_rgb(0, 0, 0)
        context.select_font_face("Sans", Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_NORMAL)
        context.set_font_size(12)
        context.move_to(x + 10, y + 20)
        context.show_text("SVG: #{File.basename(svg_file)}")
        context.move_to(x + 10, y + 40)
        context.show_text("(Installé 'librsvg' pour l'affichage SVG)")
      end

    rescue => e
      puts "Erreur lors du chargement du SVG: #{e.message}"
      context.set_source_rgb(1, 0, 0)
      context.rectangle(0, 0, width, height)
      context.fill

      context.set_source_rgb(1, 1, 1)
      context.select_font_face("Sans", Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_NORMAL)
      context.set_font_size(12)
      context.move_to(10, 20)
      context.show_text("Erreur: #{File.basename(svg_file)}")
    end
  end

  def play_animation
    return if @playing || @frames.empty?

    @playing = true
    @play_button.sensitive = false
    @pause_button.sensitive = true

    @timer_id = GLib::Timeout.add(@delay) do
      next_frame
      @playing
    end
  end

  def pause_animation
    @playing = false
    @play_button.sensitive = true
    @pause_button.sensitive = false

    if @timer_id
      GLib::Source.remove(@timer_id)
      @timer_id = nil
    end
  end

  def step_forward
    return if @frames.empty?
    @current_frame = (@current_frame + 1) % @frames.size
    update_display
  end

  def step_backward
    return if @frames.empty?
    @current_frame = (@current_frame - 1) % @frames.size
    update_display
  end

  def next_frame
    return false if @frames.empty?

    if @current_frame < @frames.size - 1
      @current_frame += 1
    elsif @loop
      @current_frame = 0
    else
      pause_animation
      return false
    end

    update_display
    true
  end

  def adjust_speed(change)
    @delay = [10, @delay + change].max  # Minimum 10ms
    @speed_label.text = "Vitesse: #{@delay}ms/image"

    # Si l'animation est en cours, redémarrer avec le nouveau délai
    if @playing
      pause_animation
      play_animation
    end
  end

  def reset_animation
    return if @frames.empty?
    @current_frame = 0
    update_display
  end

  def change_frame_by_scale
    return if @frames.empty?
    @current_frame = @frame_scale.value.to_i
    update_display
  end

  def update_display
    if @frames.empty?
      @frame_label.text = "Frame: 0/0"
    else
      @frame_label.text = "Frame: #{@current_frame + 1}/#{@frames.size}"
      @frame_scale.set_value(@current_frame)
    end
    @drawing_area.queue_draw
  end

  def enable_controls
    @play_button.sensitive = true
    @step_forward_button.sensitive = true
    @step_backward_button.sensitive = true
    @slow_button.sensitive = true
    @fast_button.sensitive = true
    @reset_button.sensitive = true
  end

  def disable_controls
    @play_button.sensitive = false
    @pause_button.sensitive = false
    @step_forward_button.sensitive = false
    @step_backward_button.sensitive = false
    @slow_button.sensitive = false
    @fast_button.sensitive = false
    @reset_button.sensitive = false
  end

  def run dir_name=nil
    if dir_name
      @directory = dir_name
      load_svg_files
    end
    @window.show_all
    Gtk.main
  end
end

# Installation des dépendances nécessaires
def check_dependencies
  puts "Vérification des dépendances..."
  begin
    require 'gtk3'
    puts "✓ GTK3 est installé"
  rescue LoadError
    puts "Erreur: GTK3 n'est pas installé"
    puts "Installez-le avec: gem install gtk3"
    exit 1
  end

  begin
    require 'rsvg2'
    puts "✓ RSVG2 est installé (pour l'affichage SVG)"
  rescue LoadError
    puts "Attention: RSVG2 n'est pas installé"
    puts "L'application fonctionnera mais n'affichera pas les SVG correctement"
    puts "Installez-le avec:"
    puts "  sudo apt-get install librsvg2-dev  # Debian/Ubuntu"
    puts "  sudo dnf install librsvg2-devel    # Fedora"
    puts "  brew install librsvg               # macOS"
    puts "Puis: gem install rsvg2"
  end

  puts "\nLancement de l'application..."
end

if __FILE__ == $0
  check_dependencies
  dir_name=ARGV.first

  app = SVGAnimationPlayer.new
  app.run dir_name
end
