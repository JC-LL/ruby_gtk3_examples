#!/usr/bin/env ruby

require 'gtk3'
require 'gtksourceview3'
require 'json'
require 'fileutils'

class SnippetManager
  def initialize
    @snippets = {}
    @syntax_config = {}
    @current_snippet_name = nil
    @current_file_path = nil
    @filtered_snippets = {}
    @row_to_snippet_map = {}  # Map pour associer les rows aux noms de snippets

    load_syntax_config('syntax_vhdl.json')
    load_snippets('snippets_vhdl.json')

    build_ui
  end

  def load_syntax_config(filename)
    if File.exist?(filename)
      @syntax_config = JSON.parse(File.read(filename))
      puts "Syntax config loaded: #{@syntax_config['language']}"
    else
      puts "Warning: Syntax config file #{filename} not found"
    end
  end

  def load_snippets(filename)
    if File.exist?(filename)
      data = JSON.parse(File.read(filename))
      @snippets = data['snippets'] || {}
      @filtered_snippets = @snippets.dup
      puts "Loaded #{@snippets.size} snippets"
    else
      puts "Warning: Snippets file #{filename} not found"
      @snippets = {}
      @filtered_snippets = {}
    end
  end

  def save_to_file(filename, content)
    File.write(filename, content)
    puts "Content saved to #{filename}"
  end

  def load_from_file(filename)
    if File.exist?(filename)
      File.read(filename)
    else
      ""
    end
  end

  def build_ui
    # Create main window
    @window = Gtk::Window.new(:toplevel)
    @window.set_title("Gestionnaire de Snippets - #{@syntax_config['language']}")
    @window.set_default_size(1000, 700)
    @window.set_size_request(800, 600) # Taille minimale
    @window.signal_connect('destroy') { Gtk.main_quit }

    # Create main horizontal box
    main_box = Gtk::Box.new(:horizontal, 10)
    main_box.set_margin_top(10)
    main_box.set_margin_bottom(10)
    main_box.set_margin_start(10)
    main_box.set_margin_end(10)
    @window.add(main_box)

    # Left panel for snippets
    left_panel = Gtk::Box.new(:vertical, 5)
    left_panel.set_size_request(250, -1) # Largeur fixe, hauteur flexible
    main_box.pack_start(left_panel, expand: false, fill: false, padding: 0)

    # Snippets header
    snippets_header = Gtk::Box.new(:horizontal, 5)
    left_panel.pack_start(snippets_header, expand: false, fill: false, padding: 0)

    @snippets_count_label = Gtk::Label.new
    update_snippets_count_label
    snippets_header.pack_start(@snippets_count_label, expand: true, fill: true, padding: 0)

    # Search box
    search_box = Gtk::Box.new(:horizontal, 5)
    left_panel.pack_start(search_box, expand: false, fill: false, padding: 5)

    search_entry = Gtk::SearchEntry.new
    search_entry.set_placeholder_text("Rechercher...")
    search_entry.signal_connect('search-changed') do |entry|
      filter_snippets(entry.text)
    end
    search_box.pack_start(search_entry, expand: true, fill: true, padding: 0)

    clear_search_btn = Gtk::Button.new(label: "X")
    clear_search_btn.set_tooltip_text("Effacer la recherche")
    clear_search_btn.signal_connect('clicked') do
      search_entry.text = ""
      filter_snippets("")
    end
    search_box.pack_start(clear_search_btn, expand: false, fill: false, padding: 0)

    # Snippets list with scroll
    snippets_frame = Gtk::Frame.new
    snippets_frame.set_shadow_type(:etched_in)
    left_panel.pack_start(snippets_frame, expand: true, fill: true, padding: 0)

    scrolled_snippets = Gtk::ScrolledWindow.new
    scrolled_snippets.set_policy(:automatic, :automatic)
    scrolled_snippets.set_min_content_height(200)
    snippets_frame.add(scrolled_snippets)

    # Use ListBox for better snippet management
    @snippets_listbox = Gtk::ListBox.new
    @snippets_listbox.set_selection_mode(:browse)
    @snippets_listbox.signal_connect('row-activated') do |listbox, row|
      snippet_name = @row_to_snippet_map[row]
      if snippet_name
        load_snippet_to_editor(snippet_name)
      end
    end
    scrolled_snippets.add(@snippets_listbox)

    # Control buttons
    controls_box = Gtk::Box.new(:vertical, 5)
    left_panel.pack_start(controls_box, expand: false, fill: false, padding: 5)

    # File operations buttons
    file_box = Gtk::Box.new(:vertical, 5)
    controls_box.pack_start(file_box, expand: false, fill: false, padding: 0)

    new_button = Gtk::Button.new(label: "Nouveau")
    new_button.signal_connect('clicked') { new_file }
    file_box.pack_start(new_button, expand: false, fill: false, padding: 0)

    open_button = Gtk::Button.new(label: "Ouvrir...")
    open_button.signal_connect('clicked') { open_file }
    file_box.pack_start(open_button, expand: false, fill: false, padding: 0)

    save_button = Gtk::Button.new(label: "Sauvegarder")
    save_button.signal_connect('clicked') { save_file }
    file_box.pack_start(save_button, expand: false, fill: false, padding: 0)

    save_as_button = Gtk::Button.new(label: "Sauvegarder sous...")
    save_as_button.signal_connect('clicked') { save_file_as }
    file_box.pack_start(save_as_button, expand: false, fill: false, padding: 0)

    # Snippet operations buttons
    snippet_box = Gtk::Box.new(:vertical, 5)
    controls_box.pack_start(snippet_box, expand: false, fill: false, padding: 0)

    reload_button = Gtk::Button.new(label: "Recharger snippet")
    reload_button.signal_connect('clicked') { reload_snippet }
    snippet_box.pack_start(reload_button, expand: false, fill: false, padding: 0)

    # Right panel for source editor - CE PANEL DOIT S'EXPANDRE
    right_panel = Gtk::Box.new(:vertical, 5)
    main_box.pack_start(right_panel, expand: true, fill: true, padding: 0)

    # Current file label
    @file_label = Gtk::Label.new("Aucun fichier")
    @file_label.set_halign(:start)
    @file_label.set_ellipsize(:middle)
    right_panel.pack_start(@file_label, expand: false, fill: false, padding: 0)

    # Create SourceView with syntax highlighting
    create_source_view

    # Scrollable source area - CRITIQUE: Doit s'expand et fill
    scrolled_source = Gtk::ScrolledWindow.new
    scrolled_source.set_policy(:automatic, :automatic)

    # IMPORTANT: Utiliser un Gtk::Viewport pour forcer le redimensionnement
    viewport = Gtk::Viewport.new
    viewport.add(@source_view)
    scrolled_source.add(viewport)

    # Le ScrolledWindow doit prendre tout l'espace disponible
    right_panel.pack_start(scrolled_source, expand: true, fill: true, padding: 0)

    # Status bar
    @status_bar = Gtk::Statusbar.new
    right_panel.pack_start(@status_bar, expand: false, fill: false, padding: 0)

    # Populate snippets list
    update_snippets_list

    @window.show_all
  end

  def create_source_view
    # Create language manager and style scheme manager
    lang_manager = GtkSource::LanguageManager.new
    style_manager = GtkSource::StyleSchemeManager.new

    # Create source buffer
    @source_buffer = GtkSource::Buffer.new

    # Try to set VHDL language
    vhdl_lang = lang_manager.get_language('vhdl')
    if vhdl_lang
      @source_buffer.language = vhdl_lang
      puts "VHDL language support loaded"
    else
      puts "VHDL language not found, using default"
      puts "Langages disponibles: #{lang_manager.language_ids.join(', ')}"
    end

    # Set a nice style scheme
    scheme = style_manager.get_scheme('classic')
    @source_buffer.style_scheme = scheme if scheme

    # Configure buffer options
    @source_buffer.highlight_syntax = true
    @source_buffer.highlight_matching_brackets = true

    # Create source view
    @source_view = GtkSource::View.new
    @source_view.buffer = @source_buffer
    @source_view.show_line_numbers = true
    @source_view.auto_indent = true
    @source_view.tab_width = 2
    @source_view.insert_spaces_instead_of_tabs = true
    @source_view.show_line_marks = true

    # CONFIGURATION DE LA MARGE DROITE
    @source_view.show_right_margin = true
    @source_view.right_margin_position = 120  # 120 colonnes au lieu de 80
    @source_view.wrap_mode = :none  # Pas de retour à la ligne automatique

    @source_view.monospace = true

    # IMPORTANT: Forcer le redimensionnement du SourceView
    @source_view.set_hexpand(true)
    @source_view.set_vexpand(true)
    @source_view.set_size_request(100, 100) # Taille minimale

    # Connect to cursor position changes
    @source_view.signal_connect('notify::cursor-position') do
      update_cursor_position
    end
  end

  def update_cursor_position
    buffer = @source_view.buffer
    cursor_iter = buffer.cursor_position
    line = cursor_iter.line + 1
    column = cursor_iter.line_index + 1
    update_status("Ligne: #{line}, Colonne: #{column}")
  end

  def filter_snippets(search_text)
    if search_text.empty?
      @filtered_snippets = @snippets.dup
    else
      search_down = search_text.downcase
      @filtered_snippets = @snippets.select do |name, content|
        name.downcase.include?(search_down) || content.downcase.include?(search_down)
      end
    end
    update_snippets_list
    update_snippets_count_label
    update_status("Filtré: #{@filtered_snippets.size} snippets sur #{@snippets.size}")
  end

  def update_snippets_count_label
    total = @snippets.size
    filtered = @filtered_snippets.size
    if total == filtered
      @snippets_count_label.set_markup("<b>Snippets (#{total})</b>")
    else
      @snippets_count_label.set_markup("<b>Snippets (#{filtered}/#{total})</b>")
    end
  end

  def update_snippets_list
    # Clear existing list and mapping
    @snippets_listbox.children.each(&:destroy)
    @row_to_snippet_map.clear

    # Add snippets to listbox
    @filtered_snippets.keys.sort.each do |snippet_name|
      row = Gtk::ListBoxRow.new

      # Create content for the row
      box = Gtk::Box.new(:horizontal, 5)
      box.set_margin_top(5)
      box.set_margin_bottom(5)
      box.set_margin_start(5)
      box.set_margin_end(5)

      label = Gtk::Label.new(snippet_name)
      label.set_halign(:start)
      label.set_ellipsize(:end)
      box.pack_start(label, expand: true, fill: true, padding: 0)

      # Add snippet preview icon/label
      preview_label = Gtk::Label.new("📄")
      preview_label.set_tooltip_text("Cliquer pour charger")
      box.pack_start(preview_label, expand: false, fill: false, padding: 0)

      row.add(box)
      @snippets_listbox.add(row)

      # Store mapping between row and snippet name
      @row_to_snippet_map[row] = snippet_name
    end

    @window.show_all
  end

  def get_snippet_name_for_row(row)
    @row_to_snippet_map[row]
  end

  def load_snippet_to_editor(snippet_name)
    if @snippets[snippet_name]
      @source_buffer.text = @snippets[snippet_name]
      @current_snippet_name = snippet_name
      @current_file_path = nil
      update_file_label("Snippet: #{snippet_name}")
      update_status("Chargé: #{snippet_name}")

      # Highlight the selected snippet in the list
      @snippets_listbox.children.each do |row|
        if get_snippet_name_for_row(row) == snippet_name
          @snippets_listbox.select_row(row)
          break
        end
      end
    end
  end

  def reload_snippet
    if @current_snippet_name && @snippets[@current_snippet_name]
      @source_buffer.text = @snippets[@current_snippet_name]
      update_status("Rechargé: #{@current_snippet_name}")
    else
      show_message("Aucun snippet sélectionné pour rechargement")
    end
  end

  def new_file
    @source_buffer.text = ""
    @current_file_path = nil
    @current_snippet_name = nil
    @snippets_listbox.unselect_all
    update_file_label("Nouveau fichier")
    update_status("Nouveau fichier créé")
  end

  def open_file
    dialog = Gtk::FileChooserDialog.new(title: "Ouvrir un fichier",
                                       parent: @window,
                                       action: :open,
                                       buttons: [[Gtk::Stock::OPEN, :accept],
                                                [Gtk::Stock::CANCEL, :cancel]])

    # Add file filters
    filter_all = Gtk::FileFilter.new
    filter_all.name = "Tous les fichiers"
    filter_all.add_pattern("*")
    dialog.add_filter(filter_all)

    filter_vhdl = Gtk::FileFilter.new
    filter_vhdl.name = "Fichiers VHDL"
    filter_vhdl.add_pattern("*.vhd")
    filter_vhdl.add_pattern("*.vhdl")
    dialog.add_filter(filter_vhdl)

    if dialog.run == :accept
      filename = dialog.filename
      content = load_from_file(filename)
      @source_buffer.text = content
      @current_file_path = filename
      @current_snippet_name = nil
      @snippets_listbox.unselect_all
      update_file_label("Fichier: #{File.basename(filename)}")
      update_status("Ouvert: #{filename}")

      # Try to detect language from file extension
      detect_language_from_filename(filename)
    end

    dialog.destroy
  end

  def detect_language_from_filename(filename)
    lang_manager = GtkSource::LanguageManager.new
    case File.extname(filename).downcase
    when '.vhd', '.vhdl'
      lang = lang_manager.get_language('vhdl')
      @source_buffer.language = lang if lang
    when '.py'
      lang = lang_manager.get_language('python')
      @source_buffer.language = lang if lang
    when '.rb'
      lang = lang_manager.get_language('ruby')
      @source_buffer.language = lang if lang
    when '.c', '.h'
      lang = lang_manager.get_language('c')
      @source_buffer.language = lang if lang
    when '.cpp', '.cc', '.cxx', '.hpp'
      lang = lang_manager.get_language('cpp')
      @source_buffer.language = lang if lang
    end
  end

  def save_file
    if @current_file_path
      save_to_file(@current_file_path, @source_buffer.text)
      update_status("Sauvegardé: #{@current_file_path}")
    else
      save_file_as
    end
  end

  def save_file_as
    dialog = Gtk::FileChooserDialog.new(title: "Sauvegarder le fichier",
                                       parent: @window,
                                       action: :save,
                                       buttons: [[Gtk::Stock::SAVE, :accept],
                                                [Gtk::Stock::CANCEL, :cancel]])

    # Add file filters
    filter_all = Gtk::FileFilter.new
    filter_all.name = "Tous les fichiers"
    filter_all.add_pattern("*")
    dialog.add_filter(filter_all)

    filter_vhdl = Gtk::FileFilter.new
    filter_vhdl.name = "Fichiers VHDL"
    filter_vhdl.add_pattern("*.vhd")
    filter_vhdl.add_pattern("*.vhdl")
    dialog.add_filter(filter_vhdl)

    # Suggest a default name
    if @current_snippet_name
      dialog.current_name = "#{@current_snippet_name.downcase.gsub(' ', '_')}.vhd"
    else
      dialog.current_name = "nouveau_fichier.vhd"
    end

    if dialog.run == :accept
      filename = dialog.filename
      save_to_file(filename, @source_buffer.text)
      @current_file_path = filename
      @current_snippet_name = nil
      @snippets_listbox.unselect_all
      update_file_label("Fichier: #{File.basename(filename)}")
      update_status("Sauvegardé sous: #{filename}")
    end

    dialog.destroy
  end

  def update_file_label(text)
    @file_label.set_text(text)
  end

  def update_status(message)
    context_id = @status_bar.get_context_id("status")
    @status_bar.push(context_id, message)
  end

  def show_message(message)
    dialog = Gtk::MessageDialog.new(parent: @window,
                                   flags: :modal,
                                   type: :info,
                                   buttons: :ok,
                                   message: message)
    dialog.run
    dialog.destroy
  end

  def run
    Gtk.main
  end
end

# Lancement de l'application
if __FILE__ == $0
  app = SnippetManager.new
  app.run
end
