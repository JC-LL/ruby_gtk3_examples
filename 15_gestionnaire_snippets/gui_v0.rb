#!/usr/bin/env ruby

require 'gtk3'
require 'json'
require 'fileutils'

class SnippetManager
  def initialize
    @snippets = {}
    @syntax_config = {}
    @current_snippet_name = nil

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

  def save_snippets(filename)
    data = { 'snippets' => @snippets }
    File.write(filename, JSON.pretty_generate(data))
    puts "Snippets saved to #{filename}"
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
    main_box.pack_start(left_panel, false, false, 0)

    # Scrollable area for buttons
    scrolled_buttons = Gtk::ScrolledWindow.new
    scrolled_buttons.set_policy(:automatic, :automatic)
    left_panel.pack_start(scrolled_buttons, true, true, 0)

    # Button container
    @button_box = Gtk::Box.new(:vertical, 5)
    scrolled_buttons.add(@button_box)

    # Control buttons
    controls_box = Gtk::Box.new(:vertical, 5)
    left_panel.pack_start(controls_box, false, false, 5)

    save_button = Gtk::Button.new(label: "Sauvegarder sous...")
    save_button.signal_connect('clicked') { save_as_snippet }
    controls_box.pack_start(save_button, false, false, 0)

    reload_button = Gtk::Button.new(label: "Recharger")
    reload_button.signal_connect('clicked') { reload_snippet }
    controls_box.pack_start(reload_button, false, false, 0)

    # Right panel for text editor
    right_panel = Gtk::Box.new(:vertical, 5)
    main_box.pack_start(right_panel, true, true, 0)

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
    right_panel.pack_start(scrolled_text, true, true, 0)

    # Status bar
    @status_bar = Gtk::Statusbar.new
    right_panel.pack_start(@status_bar, false, false, 0)

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
        regex = /\b#{Regexp.escape(keyword)}\b/i
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
      @button_box.pack_start(button, false, false, 0)
    end

    @window.show_all
  end

  def load_snippet_to_editor(snippet_name)
    if @snippets[snippet_name]
      @text_view.buffer.text = @snippets[snippet_name]
      @current_snippet_name = snippet_name
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

  def save_as_snippet
    dialog = Gtk::Dialog.new(title: "Sauvegarder le snippet",
                            parent: @window,
                            flags: :modal,
                            buttons: [[Gtk::Stock::SAVE, :accept],
                                     [Gtk::Stock::CANCEL, :cancel]])

    content_area = dialog.child
    box = Gtk::Box.new(:vertical, 10)
    box.set_margin_top(20)
    box.set_margin_bottom(20)
    box.set_margin_start(20)
    box.set_margin_end(20)
    content_area.pack_start(box, true, true, 0)

    name_label = Gtk::Label.new("Nom du snippet:")
    box.pack_start(name_label, false, false, 0)

    name_entry = Gtk::Entry.new
    name_entry.text = @current_snippet_name || "Nouveau snippet"
    box.pack_start(name_entry, false, false, 0)

    dialog.show_all

    if dialog.run == :accept
      snippet_name = name_entry.text.strip
      if !snippet_name.empty?
        @snippets[snippet_name] = @text_view.buffer.text
        @current_snippet_name = snippet_name
        update_snippet_buttons
        save_snippets('snippets_vhdl.json')
        update_status("Sauvegardé: #{snippet_name}")
      end
    end

    dialog.destroy
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
