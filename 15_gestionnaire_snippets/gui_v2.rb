#!/usr/bin/env ruby

require 'gtk3'
require 'json'
require 'fileutils'

class SnippetManager
  def initialize
    @snippets = {}
    @syntax_config = {}
    @current_snippet_name = nil
    @current_file_path = nil

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
      puts "Loaded #{@snippets.size} snippets"
    else
      puts "Warning: Snippets file #{filename} not found"
      @snippets = {}
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
    @window.signal_connect('destroy') { Gtk.main_quit }

    # Create main horizontal box
    main_box = Gtk::Box.new(:horizontal, 10)
    main_box.set_margin_top(10)
    main_box.set_margin_bottom(10)
    main_box.set_margin_start(10)
    main_box.set_margin_end(10)
    @window.add(main_box)

    # Left panel for buttons
    left_panel = Gtk::Box.new(:vertical, 5)
    left_panel.set_size_request(200, -1)
    main_box.pack_start(left_panel, expand: false, fill: false, padding: 0)

    # Scrollable area for buttons
    scrolled_buttons = Gtk::ScrolledWindow.new
    scrolled_buttons.set_policy(:automatic, :automatic)
    left_panel.pack_start(scrolled_buttons, expand: true, fill: true, padding: 0)

    # Button container
    @button_box = Gtk::Box.new(:vertical, 5)
    scrolled_buttons.add(@button_box)

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

    # Right panel for text editor
    right_panel = Gtk::Box.new(:vertical, 5)
    main_box.pack_start(right_panel, expand: true, fill: true, padding: 0)

    # Current file label
    @file_label = Gtk::Label.new("Aucun fichier")
    @file_label.set_halign(:start)
    right_panel.pack_start(@file_label, expand: false, fill: false, padding: 0)

    # Text editor with syntax highlighting
    @text_view = Gtk::TextView.new
    @text_view.set_wrap_mode(:word_char)
    @text_view.set_monospace(true)

    # Create text buffer with tag table for syntax highlighting
    create_syntax_tags(@text_view.buffer)

    # Scrollable text area
    scrolled_text = Gtk::ScrolledWindow.new
    scrolled_text.set_policy(:automatic, :automatic)
    scrolled_text.add(@text_view)
    right_panel.pack_start(scrolled_text, expand: true, fill: true, padding: 0)

    # Status bar
    @status_bar = Gtk::Statusbar.new
    right_panel.pack_start(@status_bar, expand: false, fill: false, padding: 0)

    # Populate buttons
    update_snippet_buttons

    # Connect text buffer changes for syntax highlighting
    @text_view.buffer.signal_connect('changed') { apply_syntax_highlighting }

    @window.show_all
  end

  def create_syntax_tags(buffer)
    return unless @syntax_config['keywords']

    @syntax_config['keywords'].each do |category, config|
      tag_name = "syntax_#{category}"
      color = Gdk::RGBA.parse(config['color'])
      buffer.create_tag(tag_name,
                       'foreground_rgba' => color,
                       'weight' => Pango::Weight::BOLD)
    end

    # Default tag for normal text
    buffer.create_tag('syntax_normal', 'weight' => Pango::Weight::NORMAL)
  end

  def apply_syntax_highlighting
    return unless @syntax_config['keywords']

    buffer = @text_view.buffer
    text = buffer.text

    # Remove existing highlighting
    buffer.remove_all_tags(buffer.start_iter, buffer.end_iter)

    # Apply syntax highlighting for each category
    @syntax_config['keywords'].each do |category, config|
      config['words'].each do |keyword|
        # Use regex to find whole words only
        start_iter = buffer.start_iter

        while match = start_iter.forward_search(keyword, :text_only, nil)
          start_match, end_match = match
          buffer.apply_tag("syntax_#{category}", start_match, end_match)
          start_iter = end_match
        end
      end
    end
  end

  def update_snippet_buttons
    # Clear existing buttons
    @button_box.children.each(&:destroy)

    # Create buttons for each snippet
    @snippets.keys.sort.each do |snippet_name|
      button = Gtk::Button.new(label: snippet_name)
      button.signal_connect('clicked') do
        load_snippet_to_editor(snippet_name)
      end
      @button_box.pack_start(button, expand: false, fill: false, padding: 0)
    end

    @window.show_all
  end

  def load_snippet_to_editor(snippet_name)
    if @snippets[snippet_name]
      @text_view.buffer.text = @snippets[snippet_name]
      @current_snippet_name = snippet_name
      @current_file_path = nil
      update_file_label("Snippet: #{snippet_name}")
      update_status("Chargé: #{snippet_name}")
    end
  end

  def reload_snippet
    if @current_snippet_name && @snippets[@current_snippet_name]
      @text_view.buffer.text = @snippets[@current_snippet_name]
      update_status("Rechargé: #{@current_snippet_name}")
    else
      show_message("Aucun snippet sélectionné pour rechargement")
    end
  end

  def new_file
    @text_view.buffer.text = ""
    @current_file_path = nil
    @current_snippet_name = nil
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
    filter = Gtk::FileFilter.new
    filter.name = "Tous les fichiers"
    filter.add_pattern("*")
    dialog.add_filter(filter)

    if dialog.run == :accept
      filename = dialog.filename
      content = load_from_file(filename)
      @text_view.buffer.text = content
      @current_file_path = filename
      @current_snippet_name = nil
      update_file_label("Fichier: #{File.basename(filename)}")
      update_status("Ouvert: #{filename}")
    end

    dialog.destroy
  end

  def save_file
    if @current_file_path
      save_to_file(@current_file_path, @text_view.buffer.text)
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
    filter = Gtk::FileFilter.new
    filter.name = "Tous les fichiers"
    filter.add_pattern("*")
    dialog.add_filter(filter)

    # Suggest a default name
    if @current_snippet_name
      dialog.current_name = "#{@current_snippet_name.downcase.gsub(' ', '_')}.vhd"
    else
      dialog.current_name = "nouveau_fichier.vhd"
    end

    if dialog.run == :accept
      filename = dialog.filename
      save_to_file(filename, @text_view.buffer.text)
      @current_file_path = filename
      @current_snippet_name = nil
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
