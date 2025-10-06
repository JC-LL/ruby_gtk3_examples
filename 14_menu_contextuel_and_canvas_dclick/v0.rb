require 'gtk3'

class SaisieFenetre < Gtk::Window
  def initialize(titre = "Saisie d'informations")
    super(:toplevel)

    set_title(titre)
    set_default_size(300, 200)
    set_window_position(:center)

    # Conteneur principal
    vbox = Gtk::Box.new(:vertical, 10)
    vbox.set_margin_top(10)
    vbox.set_margin_bottom(10)
    vbox.set_margin_start(10)
    vbox.set_margin_end(10)

    # Champ de saisie pour le nom
    hbox_nom = Gtk::Box.new(:horizontal, 5)
    label_nom = Gtk::Label.new("Nom:")
    @entry_nom = Gtk::Entry.new
    hbox_nom.pack_start(label_nom, expand: false, fill: false, padding: 0)
    hbox_nom.pack_start(@entry_nom, expand: true, fill: true, padding: 0)

    # Champ de saisie pour l'email
    hbox_email = Gtk::Box.new(:horizontal, 5)
    label_email = Gtk::Label.new("Email:")
    @entry_email = Gtk::Entry.new
    hbox_email.pack_start(label_email, expand: false, fill: false, padding: 0)
    hbox_email.pack_start(@entry_email, expand: true, fill: true, padding: 0)

    # Zone de texte pour description
    label_desc = Gtk::Label.new("Description:")
    @textview_desc = Gtk::TextView.new
    @textview_desc.set_size_request(-1, 80)

    # Boutons
    hbox_buttons = Gtk::Box.new(:horizontal, 5)
    btn_ok = Gtk::Button.new(label: "OK")
    btn_cancel = Gtk::Button.new(label: "Annuler")

    hbox_buttons.pack_end(btn_cancel, expand: false, fill: false, padding: 0)
    hbox_buttons.pack_end(btn_ok, expand: false, fill: false, padding: 0)

    # Assemblage de l'interface
    vbox.pack_start(hbox_nom, expand: false, fill: false, padding: 0)
    vbox.pack_start(hbox_email, expand: false, fill: false, padding: 0)
    vbox.pack_start(label_desc, expand: false, fill: false, padding: 0)
    vbox.pack_start(@textview_desc, expand: true, fill: true, padding: 0)
    vbox.pack_start(hbox_buttons, expand: false, fill: false, padding: 0)

    add(vbox)

    # Connexion des signaux
    btn_ok.signal_connect('clicked') do
      on_ok_clicked
    end

    btn_cancel.signal_connect('clicked') do
      destroy
    end

    # Fermeture avec la touche Échap
    signal_connect('key-press-event') do |_widget, event|
      if event.keyval == Gdk::Keyval::KEY_Escape
        destroy
      end
    end
  end

  def on_ok_clicked
    nom = @entry_nom.text
    email = @entry_email.text
    buffer = @textview_desc.buffer
    description = buffer.get_text(buffer.start_iter, buffer.end_iter, true)

    puts "=== Données saisies ==="
    puts "Nom: #{nom}"
    puts "Email: #{email}"
    puts "Description: #{description}"
    puts "======================="

    destroy
  end
end

class ApplicationFenetre < Gtk::Window
  def initialize
    super(:toplevel)

    set_title("Exemple Menu Contextuel et Double-Clic")
    set_default_size(600, 400)
    set_window_position(:center)

    # Création du canvas (DrawingArea)
    @canvas = Gtk::DrawingArea.new

    # Configuration des événements du canvas
    @canvas.add_events(Gdk::EventMask::BUTTON_PRESS_MASK)
    @canvas.add_events(Gdk::EventMask::BUTTON_RELEASE_MASK)

    @canvas.signal_connect('draw') { |widget, cr| dessiner_canvas(widget, cr) }
    @canvas.signal_connect('button-press-event') do |_widget, event|
      on_canvas_click(event)
    end

    # Variables pour détection du double-clic
    @dernier_clic_time = 0
    @dernier_clic_x = 0
    @dernier_clic_y = 0

    # Menu contextuel
    @menu_contextuel = creer_menu_contextuel

    # Élément sélectionnable (simulé par un rectangle)
    @element_selectionne = { x: 100, y: 100, width: 150, height: 80, selected: false }

    # Layout principal
    vbox = Gtk::Box.new(:vertical, 5)

    # Barre d'info
    @label_info = Gtk::Label.new("Faites un clic droit pour le menu contextuel ou double-cliquez sur le rectangle")

    vbox.pack_start(@label_info, expand: false, fill: false, padding: 0)
    vbox.pack_start(@canvas, expand: true, fill: true, padding: 0)

    add(vbox)

    # Connexion du signal de fermeture
    signal_connect('destroy') { Gtk.main_quit }
  end

  def creer_menu_contextuel
    menu = Gtk::Menu.new

    # Élément de menu pour ouvrir la fenêtre de saisie
    item_saisie = Gtk::MenuItem.new(label: "Ouvrir fenêtre de saisie")
    item_saisie.signal_connect('activate') do
      fenetre_saisie = SaisieFenetre.new("Saisie depuis menu contextuel")
      fenetre_saisie.show_all
    end

    # Séparateur
    separator = Gtk::SeparatorMenuItem.new

    # Élément de menu pour quitter
    item_quitter = Gtk::MenuItem.new(label: "Quitter")
    item_quitter.signal_connect('activate') { Gtk.main_quit }

    menu.append(item_saisie)
    menu.append(separator)
    menu.append(item_quitter)

    menu
  end

  def dessiner_canvas(widget, cr)
    width = widget.allocated_width
    height = widget.allocated_height

    # Fond blanc
    cr.set_source_rgb(1, 1, 1)
    cr.paint

    # Dessiner un élément sélectionnable
    if @element_selectionne[:selected]
      cr.set_source_rgb(0.8, 0.8, 1.0) # Bleu clair quand sélectionné
    else
      cr.set_source_rgb(0.7, 0.7, 0.7) # Gris normal
    end

    cr.rectangle(@element_selectionne[:x], @element_selectionne[:y],
                 @element_selectionne[:width], @element_selectionne[:height])
    cr.fill

    # Bordure
    cr.set_source_rgb(0, 0, 0)
    cr.rectangle(@element_selectionne[:x], @element_selectionne[:y],
                 @element_selectionne[:width], @element_selectionne[:height])
    cr.stroke

    # Texte dans l'élément
    cr.set_source_rgb(0, 0, 0)
    cr.select_font_face("Sans", Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_NORMAL)
    cr.set_font_size(12)
    cr.move_to(@element_selectionne[:x] + 10, @element_selectionne[:y] + 30)
    cr.show_text("Double-cliquez ici")
  end

  def on_canvas_click(event)
    case event.button
    when 1 # Clic gauche
      # Vérifier si on clique sur l'élément
      x = event.x
      y = event.y
      element = @element_selectionne

      if x >= element[:x] && x <= element[:x] + element[:width] &&
         y >= element[:y] && y <= element[:y] + element[:height]

        # Détection du double-clic
        temps_actuel = Time.now.to_f
        delta_temps = temps_actuel - @dernier_clic_time
        delta_x = (x - @dernier_clic_x).abs
        delta_y = (y - @dernier_clic_y).abs

        # Si le clic est assez rapide et proche du précédent, c'est un double-clic
        if delta_temps < 0.5 && delta_x < 10 && delta_y < 10
          # Double-clic détecté
          fenetre_saisie = SaisieFenetre.new("Saisie depuis double-clic")
          fenetre_saisie.show_all
        else
          # Simple clic - sélectionner l'élément
          @element_selectionne[:selected] = true
          @canvas.queue_draw
        end

        # Mettre à jour les informations du dernier clic
        @dernier_clic_time = temps_actuel
        @dernier_clic_x = x
        @dernier_clic_y = y

      else
        @element_selectionne[:selected] = false
        @canvas.queue_draw
      end

    when 3 # Clic droit
      @menu_contextuel.show_all
      @menu_contextuel.popup(nil, nil, event.button, event.time)
    end
  end
end

# Lancement de l'application
app = ApplicationFenetre.new
app.show_all

Gtk.main
