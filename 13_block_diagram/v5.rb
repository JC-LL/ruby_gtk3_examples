require 'gtk3'

class CodeEditor < Gtk::Dialog
  attr_reader :input_ports, :output_ports

  def initialize(parent, block)
    super(title: "Éditeur - Bloc #{block.id}",
          parent: parent,
          flags: :modal,
          buttons: [[Gtk::Stock::OK, Gtk::ResponseType::OK],
                   [Gtk::Stock::CANCEL, Gtk::ResponseType::CANCEL]])

    @block = block
    @input_ports = @block.input_ports.dup
    @output_ports = @block.output_ports.dup

    main_box = Gtk::Box.new(:vertical, 10)
    main_box.set_margin_top(10)
    main_box.set_margin_bottom(10)
    main_box.set_margin_start(10)
    main_box.set_margin_end(10)

    # === SECTION PORTS ===
    ports_frame = Gtk::Frame.new("Ports du Bloc")
    ports_box = Gtk::Box.new(:vertical, 5)
    ports_frame.add(ports_box)

    # Instructions pour ajouter des ports
    instructions_label = Gtk::Label.new
    instructions_label.markup = "Pour ajouter un port: <b>Ctrl+I</b> (Entrée) ou <b>Ctrl+O</b> (Sortie)"
    instructions_label.set_xalign(0)
    ports_box.pack_start(instructions_label, expand: false, fill: false, padding: 5)

    # Liste des ports
    @ports_list = Gtk::Box.new(:vertical, 5)
    ports_box.pack_start(@ports_list, expand: true, fill: true, padding: 5)

    # Charger les ports existants
    refresh_ports_list

    # === SECTION CODE ===
    code_frame = Gtk::Frame.new("Code Ruby")
    scrolled_window = Gtk::ScrolledWindow.new
    scrolled_window.set_policy(:automatic, :automatic)
    scrolled_window.set_size_request(500, 300)

    @text_view = Gtk::TextView.new
    @text_view.buffer.text = @block.code || "# Code Ruby pour le bloc #{block.id}\nputs 'Hello from block #{block.id}'"

    scrolled_window.add(@text_view)
    code_frame.add(scrolled_window)

    # Assemblage
    main_box.pack_start(ports_frame, expand: false, fill: false, padding: 0)
    main_box.pack_start(code_frame, expand: true, fill: true, padding: 0)

    box = self.content_area
    box.pack_start(main_box, expand: true, fill: true, padding: 0)

    # Connexion des raccourcis clavier
    signal_connect('key-press-event') { |widget, event| on_key_press(event) }

    show_all
  end

  def on_key_press(event)
    keyval = event.keyval
    state = event.state

    # Ctrl+I pour ajouter port d'entrée
    if keyval == Gdk::Keyval::KEY_i && (state & Gdk::ModifierType::CONTROL_MASK != 0)
      add_port_dialog(:input)
      return true
    end

    # Ctrl+O pour ajouter port de sortie
    if keyval == Gdk::Keyval::KEY_o && (state & Gdk::ModifierType::CONTROL_MASK != 0)
      add_port_dialog(:output)
      return true
    end

    false
  end

  def add_port_dialog(direction)
    dialog = PortEditor.new(self, nil, direction)
    response = dialog.run
    if response == Gtk::ResponseType::OK
      port = Port.new(dialog.name, dialog.type, direction)
      if direction == :input
        @input_ports << port
      else
        @output_ports << port
      end
      refresh_ports_list
    end
    dialog.destroy
  end

  def remove_port(port, direction)
    if direction == :input
      @input_ports.delete(port)
    else
      @output_ports.delete(port)
    end
    refresh_ports_list
  end

  def edit_port(port, direction)
    dialog = PortEditor.new(self, port, direction)
    response = dialog.run
    if response == Gtk::ResponseType::OK
      port.name = dialog.name
      port.type = dialog.type
      refresh_ports_list
    end
    dialog.destroy
  end

  def refresh_ports_list
    # Vider la liste
    @ports_list.children.each { |child| @ports_list.remove(child) }

    # Ports d'entrée
    if !@input_ports.empty?
      input_label = Gtk::Label.new
      input_label.markup = "<b>Entrées:</b>"
      input_label.set_xalign(0)
      @ports_list.pack_start(input_label, expand: false, fill: false, padding: 0)

      @input_ports.each do |port|
        @ports_list.pack_start(create_port_row(port, :input), expand: false, fill: false, padding: 0)
      end
    end

    # Ports de sortie
    if !@output_ports.empty?
      output_label = Gtk::Label.new
      output_label.markup = "<b>Sorties:</b>"
      output_label.set_xalign(0)
      output_label.set_margin_top(10) if !@input_ports.empty?
      @ports_list.pack_start(output_label, expand: false, fill: false, padding: 0)

      @output_ports.each do |port|
        @ports_list.pack_start(create_port_row(port, :output), expand: false, fill: false, padding: 0)
      end
    end

    # Message si aucun port
    if @input_ports.empty? && @output_ports.empty?
      empty_label = Gtk::Label.new("Aucun port défini. Utilisez Ctrl+I ou Ctrl+O pour en ajouter.")
      empty_label.set_xalign(0)
      @ports_list.pack_start(empty_label, expand: false, fill: false, padding: 0)
    end

    @ports_list.show_all
  end

  def create_port_row(port, direction)
    row = Gtk::Box.new(:horizontal, 5)

    # Icône selon la direction
    icon_label = Gtk::Label.new
    icon_label.markup = direction == :input ? "⬅️" : "➡️"

    # Info du port
    info_label = Gtk::Label.new
    info_label.markup = "<b>#{port.name}</b> (#{port.type})"
    info_label.set_xalign(0)

    # Bouton Modifier (simple label cliquable pour éviter le core dump)
    edit_label = Gtk::Label.new
    edit_label.markup = "<span foreground='blue' underline='single'>Modifier</span>"
    edit_label.set_tooltip_text("Modifier le port")

    # Bouton Supprimer (simple label cliquable)
    delete_label = Gtk::Label.new
    delete_label.markup = "<span foreground='red' underline='single'>Supprimer</span>"
    delete_label.set_tooltip_text("Supprimer le port")

    # Utiliser des EventBox pour rendre les labels cliquables
    edit_event = Gtk::EventBox.new
    edit_event.add(edit_label)
    edit_event.signal_connect("button-press-event") { edit_port(port, direction) }

    delete_event = Gtk::EventBox.new
    delete_event.add(delete_label)
    delete_event.signal_connect("button-press-event") { remove_port(port, direction) }

    row.pack_start(icon_label, expand: false, fill: false, padding: 0)
    row.pack_start(info_label, expand: true, fill: true, padding: 0)
    row.pack_start(edit_event, expand: false, fill: false, padding: 0)
    row.pack_start(delete_event, expand: false, fill: false, padding: 0)

    row
  end

  def code
    @text_view.buffer.text
  end
end

class PortEditor < Gtk::Dialog
  def initialize(parent, port, direction = nil)
    title = port ? "Modifier le Port" : "Nouveau Port"
    super(title: title,
          parent: parent,
          flags: :modal,
          buttons: [[Gtk::Stock::OK, Gtk::ResponseType::OK],
                   [Gtk::Stock::CANCEL, Gtk::ResponseType::CANCEL]])

    @port = port
    @direction = direction || (port ? port.direction : :input)

    grid = Gtk::Grid.new
    grid.set_row_spacing(8)
    grid.set_column_spacing(8)
    grid.set_margin_top(15)
    grid.set_margin_bottom(15)
    grid.set_margin_start(15)
    grid.set_margin_end(15)

    # Direction (affichage seulement)
    direction_label = Gtk::Label.new("Direction:")
    direction_value = Gtk::Label.new(@direction == :input ? "Entrée (Input)" : "Sortie (Output)")
    direction_value.set_xalign(0)
    grid.attach(direction_label, 0, 0, 1, 1)
    grid.attach(direction_value, 1, 0, 1, 1)

    # Nom du port
    name_label = Gtk::Label.new("Nom:")
    @name_entry = Gtk::Entry.new
    @name_entry.text = port ? port.name : "port#{rand(1000)}"
    grid.attach(name_label, 0, 1, 1, 1)
    grid.attach(@name_entry, 1, 1, 1, 1)

    # Type du port
    type_label = Gtk::Label.new("Type:")
    @type_combo = Gtk::ComboBoxText.new
    ["any", "int", "float", "string", "bool", "data"].each { |t| @type_combo.append_text(t) }
    if port
      index = ["any", "int", "float", "string", "bool", "data"].index(port.type) || 0
      @type_combo.active = index
    else
      @type_combo.active = 0
    end
    grid.attach(type_label, 0, 2, 1, 1)
    grid.attach(@type_combo, 1, 2, 1, 1)

    box = self.content_area
    box.pack_start(grid, expand: true, fill: true, padding: 0)

    # Donner le focus au champ nom
    @name_entry.grab_focus

    show_all
  end

  def name
    @name_entry.text
  end

  def type
    @type_combo.active_text || "any"
  end

  def direction
    @direction
  end
end

class Port
  attr_accessor :name, :type, :direction, :x, :y, :width, :height, :connections

  def initialize(name = "port", type = "any", direction = :input)
    @name = name
    @type = type
    @direction = direction
    @x = 0
    @y = 0
    @width = 12
    @height = 12
    @connections = []
  end

  def contains?(px, py)
    center_x = @x + @width / 2
    center_y = @y + @height / 2
    radius = @width / 2

    distance = Math.sqrt((px - center_x)**2 + (py - center_y)**2)
    distance <= radius
  end

  def center_x
    @x + @width / 2
  end

  def center_y
    @y + @height / 2
  end
end

class Connection
  attr_accessor :source_port, :target_ports

  def initialize(source_port)
    @source_port = source_port
    @target_ports = []
  end

  def add_target(target_port)
    @target_ports << target_port unless @target_ports.include?(target_port)
  end

  def remove_target(target_port)
    @target_ports.delete(target_port)
  end
end

class Block
  attr_accessor :x, :y, :width, :height, :id, :code, :selected, :input_ports, :output_ports
  attr_reader :handles

  @@next_id = 1

  def initialize(x, y, width, height)
    @x = x
    @y = y
    @width = width
    @height = height
    @id = @@next_id
    @@next_id += 1
    @code = ""
    @selected = false
    @handles = []
    @input_ports = []
    @output_ports = []
    create_handles
  end

  def update_ports_position
    port_spacing = 20

    @input_ports.each_with_index do |port, index|
      port.x = @x - port.width / 2
      port.y = @y + 25 + index * port_spacing
    end

    @output_ports.each_with_index do |port, index|
      port.x = @x + @width - port.width / 2
      port.y = @y + 25 + index * port_spacing
    end
  end

  def create_handles
    handle_size = 8
    half_handle = handle_size / 2

    @handles = [
      { x: @x - half_handle, y: @y - half_handle, type: :nw, cursor: :top_left_corner },
      { x: @x + @width - half_handle, y: @y - half_handle, type: :ne, cursor: :top_right_corner },
      { x: @x - half_handle, y: @y + @height - half_handle, type: :sw, cursor: :bottom_left_corner },
      { x: @x + @width - half_handle, y: @y + @height - half_handle, type: :se, cursor: :bottom_right_corner },
      { x: @x - half_handle, y: @y + @height / 2 - half_handle, type: :w, cursor: :left_side },
      { x: @x + @width - half_handle, y: @y + @height / 2 - half_handle, type: :e, cursor: :right_side },
      { x: @x + @width / 2 - half_handle, y: @y - half_handle, type: :n, cursor: :top_side },
      { x: @x + @width / 2 - half_handle, y: @y + @height - half_handle, type: :s, cursor: :bottom_side }
    ]
  end

  def contains?(px, py)
    px >= @x && px <= @x + @width && py >= @y && py <= @y + @height
  end

  def port_at(px, py)
    all_ports = @input_ports + @output_ports
    all_ports.find { |port| port.contains?(px, py) }
  end

  def handle_at(px, py)
    handle_size = 8
    @handles.find do |handle|
      px >= handle[:x] && px <= handle[:x] + handle_size &&
      py >= handle[:y] && py <= handle[:y] + handle_size
    end
  end

  def move(dx, dy)
    @x += dx
    @y += dy
    create_handles
    update_ports_position
  end

  def resize(handle_type, dx, dy)
    case handle_type
    when :nw
      @x += dx
      @y += dy
      @width -= dx
      @height -= dy
    when :ne
      @y += dy
      @width += dx
      @height -= dy
    when :sw
      @x += dx
      @width -= dx
      @height += dy
    when :se
      @width += dx
      @height += dy
    when :n
      @y += dy
      @height -= dy
    when :s
      @height += dy
    when :w
      @x += dx
      @width -= dx
    when :e
      @width += dx
    end

    @width = [@width, 50].max
    @height = [@height, 50].max

    create_handles
    update_ports_position
  end
end

class Canvas < Gtk::DrawingArea
  attr_accessor :blocks, :current_block, :drag_start, :drag_offset, :selected_block, :resizing_handle,
                :connections, :temp_connection, :selected_port, :context_menu_block

  def initialize
    super
    @blocks = []
    @current_block = nil
    @drag_start = nil
    @drag_offset = nil
    @selected_block = nil
    @resizing_handle = nil
    @double_click_in_progress = false
    @connections = []
    @temp_connection = nil
    @selected_port = nil
    @context_menu_block = nil
    @connecting_mode = false

    set_events(Gdk::EventMask::BUTTON_PRESS_MASK |
               Gdk::EventMask::BUTTON_RELEASE_MASK |
               Gdk::EventMask::POINTER_MOTION_MASK |
               Gdk::EventMask::LEAVE_NOTIFY_MASK)

    signal_connect("draw") { |widget, cr| draw(widget, cr) }
    signal_connect("button-press-event") { |widget, event| button_press(widget, event) }
    signal_connect("button-release-event") { |widget, event| button_release(widget, event) }
    signal_connect("motion-notify-event") { |widget, event| motion_notify(widget, event) }

    @last_click_time = 0

    setup_context_menu
  end

  def setup_context_menu
    @context_menu = Gtk::Menu.new

    delete_block_item = Gtk::MenuItem.new(label: "Supprimer le bloc")
    delete_block_item.signal_connect("activate") { delete_selected_block }
    @context_menu.append(delete_block_item)

    @context_menu.show_all
  end

  def delete_selected_block
    return unless @context_menu_block

    # Supprimer aussi toutes les connexions associées à ce bloc
    @connections.reject! do |connection|
      connection.source_port.block == @context_menu_block ||
      connection.target_ports.any? { |target| target.block == @context_menu_block }
    end

    @blocks.delete(@context_menu_block)
    @selected_block = nil if @selected_block == @context_menu_block
    puts "Bloc #{@context_menu_block.id} supprimé"
    queue_draw
  end

  def draw(widget, cr)
    cr.set_source_rgb(0.1, 0.1, 0.1)
    cr.paint

    # Dessiner les connexions permanentes d'abord (en arrière-plan)
    draw_connections(cr)

    # Dessiner tous les blocs
    @blocks.each do |block|
      draw_block(cr, block)
    end

    # Dessiner le bloc en cours de création
    if @current_block
      draw_block(cr, @current_block)
    end

    # Dessiner la connexion temporaire (par dessus tout)
    draw_temp_connection(cr) if @temp_connection
  end

  def draw_connections(cr)
    @connections.each do |connection|
      source = connection.source_port
      connection.target_ports.each do |target|
        draw_connection_line(cr, source, target, permanent: true)
      end
    end
  end

  def draw_temp_connection(cr)
    return unless @temp_connection && @temp_connection[:source]

    source = @temp_connection[:source]
    target = @temp_connection[:target]

    if target.is_a?(Port)
      # Connexion vers un port - utiliser une courbe
      draw_connection_line(cr, source, target, permanent: false)
    else
      # Connexion temporaire vers la souris - ligne droite
      draw_straight_line(cr, source, target)
    end
  end

  def draw_connection_line(cr, source, target, permanent: true)
    start_x = source.center_x
    start_y = source.center_y
    end_x = target.center_x
    end_y = target.center_y

    if permanent
      # Connexion permanente - courbe de Bézier
      cr.set_source_rgb(0.5, 0.8, 0.5) # Vert
      cr.set_line_width(2)

      # Points de contrôle pour la courbe
      control_offset = [(end_x - start_x).abs * 0.5, 50].max
      control1_x = start_x + control_offset
      control1_y = start_y
      control2_x = end_x - control_offset
      control2_y = end_y

      cr.move_to(start_x, start_y)
      cr.curve_to(control1_x, control1_y, control2_x, control2_y, end_x, end_y)
      cr.stroke

      # Flèche à la fin
      draw_arrow(cr, end_x, end_y, control2_x, control2_y)
    else
      # Connexion temporaire - ligne pointillée
      cr.set_source_rgb(0.8, 0.8, 0.2) # Jaune
      cr.set_line_width(2)
      cr.set_dash([5.0, 5.0]) # Ligne pointillée

      cr.move_to(start_x, start_y)
      cr.line_to(end_x, end_y)
      cr.stroke
      cr.set_dash([]) # Réinitialiser le style de ligne
    end
  end

  def draw_straight_line(cr, source, target)
    start_x = source.center_x
    start_y = source.center_y
    end_x = target[:x]
    end_y = target[:y]

    cr.set_source_rgb(0.8, 0.8, 0.2) # Jaune
    cr.set_line_width(2)
    cr.set_dash([5.0, 5.0]) # Ligne pointillée

    cr.move_to(start_x, start_y)
    cr.line_to(end_x, end_y)
    cr.stroke
    cr.set_dash([]) # Réinitialiser le style de ligne
  end

  def draw_arrow(cr, x, y, control_x, control_y)
    # Calculer la direction de la flèche
    dx = x - control_x
    dy = y - control_y
    length = Math.sqrt(dx*dx + dy*dy)

    return if length == 0

    # Normaliser
    dx /= length
    dy /= length

    # Taille de la flèche
    arrow_size = 8

    # Points de la flèche
    arrow_x1 = x - dx * arrow_size - dy * arrow_size * 0.5
    arrow_y1 = y - dy * arrow_size + dx * arrow_size * 0.5
    arrow_x2 = x - dx * arrow_size + dy * arrow_size * 0.5
    arrow_y2 = y - dy * arrow_size - dx * arrow_size * 0.5

    cr.set_source_rgb(0.5, 0.8, 0.5)
    cr.move_to(x, y)
    cr.line_to(arrow_x1, arrow_y1)
    cr.move_to(x, y)
    cr.line_to(arrow_x2, arrow_y2)
    cr.stroke
  end

  def draw_block(cr, block)
    if block.selected
      cr.set_source_rgb(0.3, 0.3, 0.6)
    else
      cr.set_source_rgb(0.2, 0.2, 0.2)
    end
    cr.rectangle(block.x, block.y, block.width, block.height)
    cr.fill_preserve
    cr.set_source_rgb(0.7, 0.7, 0.7)
    cr.set_line_width(1)
    cr.stroke

    cr.set_source_rgb(0.9, 0.9, 0.9)
    cr.select_font_face("Sans", Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_NORMAL)
    cr.set_font_size(12)
    text = "Bloc #{block.id}"
    extents = cr.text_extents(text)
    cr.move_to(block.x + block.width / 2 - extents.width / 2,
               block.y + 15)
    cr.show_text(text)

    draw_ports(cr, block)

    if block.selected
      block.handles.each do |handle|
        cr.set_source_rgb(0.8, 0.2, 0.2)
        cr.rectangle(handle[:x], handle[:y], 8, 8)
        cr.fill
      end
    end
  end

  def draw_ports(cr, block)
    block.input_ports.each do |port|
      draw_port_shape(cr, port, :input)

      cr.set_source_rgb(0.9, 0.9, 0.9)
      cr.set_font_size(8)
      extents = cr.text_extents(port.name)
      cr.move_to(port.x - extents.width - 3, port.y + port.height / 2 + 2)
      cr.show_text(port.name)
    end

    block.output_ports.each do |port|
      draw_port_shape(cr, port, :output)

      cr.set_source_rgb(0.9, 0.9, 0.9)
      cr.set_font_size(8)
      extents = cr.text_extents(port.name)
      cr.move_to(port.x + port.width + 3, port.y + port.height / 2 + 2)
      cr.show_text(port.name)
    end
  end

  def draw_port_shape(cr, port, direction)
    center_x = port.center_x
    center_y = port.center_y
    radius = port.width / 2

    if port == @selected_port
      cr.set_source_rgb(1.0, 0.8, 0.0)
    else
      case direction
      when :input
        cr.set_source_rgb(0.2, 0.8, 0.2)
      when :output
        cr.set_source_rgb(0.8, 0.2, 0.2)
      end
    end

    cr.arc(center_x, center_y, radius, 0, 2 * Math::PI)
    cr.fill

    cr.set_source_rgb(0.9, 0.9, 0.9)
    cr.set_line_width(1)
    cr.arc(center_x, center_y, radius, 0, 2 * Math::PI)
    cr.stroke

    cr.set_source_rgb(1, 1, 1)
    cr.set_line_width(1)
    case direction
    when :input
      cr.move_to(center_x - radius/2, center_y)
      cr.line_to(center_x + radius/2, center_y)
      cr.move_to(center_x + radius/3, center_y - radius/3)
      cr.line_to(center_x + radius/2, center_y)
      cr.line_to(center_x + radius/3, center_y + radius/3)
    when :output
      cr.move_to(center_x + radius/2, center_y)
      cr.line_to(center_x - radius/2, center_y)
      cr.move_to(center_x - radius/3, center_y - radius/3)
      cr.line_to(center_x - radius/2, center_y)
      cr.line_to(center_x - radius/3, center_y + radius/3)
    end
    cr.stroke
  end

  def button_press(widget, event)
    return true if @double_click_in_progress

    case event.button
    when 1
      handle_left_click(event.x, event.y)
    when 3
      handle_right_click(event.x, event.y)
    end

    current_time = Time.now.to_f
    if current_time - @last_click_time < 0.3 && event.button == 1
      @double_click_in_progress = true
      handle_double_click(event.x, event.y)
      GLib::Timeout.add(100) { @double_click_in_progress = false }
    end
    @last_click_time = current_time

    true
  end

  def handle_right_click(x, y)
    clicked_block = @blocks.reverse.find { |block| block.contains?(x, y) }
    if clicked_block
      @context_menu_block = clicked_block
      @context_menu.popup(nil, nil, 3, Gdk::CURRENT_TIME)
    end
  end

  def handle_left_click(x, y)
    # Vérifier si on clique sur un port
    clicked_port = find_port_at(x, y)
    if clicked_port
      handle_port_click(clicked_port, x, y)
      return
    end

    # Si on est en mode connexion et qu'on clique ailleurs, annuler
    if @temp_connection
      @temp_connection = nil
      queue_draw
      return
    end

    # Vérifier si on clique sur une poignée de redimensionnement
    if @selected_block
      handle = @selected_block.handle_at(x, y)
      if handle
        @resizing_handle = handle
        @drag_start = { x: x, y: y }
        return
      end
    end

    # Vérifier si on clique sur un bloc existant
    clicked_block = @blocks.reverse.find { |block| block.contains?(x, y) }

    if clicked_block
      @selected_block.selected = false if @selected_block
      @selected_block = clicked_block
      @selected_block.selected = true
      @drag_start = { x: x, y: y }
      @drag_offset = { x: x - clicked_block.x, y: y - clicked_block.y }
    else
      @selected_block.selected = false if @selected_block
      @selected_block = nil
      @selected_port = nil
      @current_block = Block.new(x, y, 0, 0)
      @drag_start = { x: x, y: y }
    end

    queue_draw
  end

  def find_port_at(x, y)
    @blocks.each do |block|
      port = block.port_at(x, y)
      return port if port
    end
    nil
  end

  def handle_port_click(port, x, y)
    @selected_port = port

    if port.direction == :output
      # Commencer une nouvelle connexion depuis un port de sortie
      @temp_connection = { source: port, target: { x: x, y: y } }
      puts "Début de connexion depuis le port #{port.name}"
    else
      # Si on clique sur un port d'entrée et qu'il y a une connexion temporaire
      if @temp_connection && @temp_connection[:source]
        source_port = @temp_connection[:source]

        # Vérifier qu'on ne connecte pas un port à lui-même
        if source_port != port
          # Créer ou trouver la connexion existante
          connection = find_or_create_connection(source_port)
          connection.add_target(port)
          @temp_connection = nil
          puts "Connexion créée: #{source_port.name} → #{port.name}"
        else
          puts "Impossible de connecter un port à lui-même"
          @temp_connection = nil
        end
      end
    end

    queue_draw
  end

  def find_or_create_connection(source_port)
    existing = @connections.find { |conn| conn.source_port == source_port }
    unless existing
      existing = Connection.new(source_port)
      @connections << existing
    end
    existing
  end

  def handle_double_click(x, y)
    clicked_block = @blocks.reverse.find { |block| block.contains?(x, y) }
    if clicked_block
      @drag_start = nil
      @drag_offset = nil
      editor = CodeEditor.new(self.toplevel, clicked_block)
      response = editor.run
      if response == Gtk::ResponseType::OK
        clicked_block.input_ports = editor.input_ports
        clicked_block.output_ports = editor.output_ports
        clicked_block.code = editor.code
        clicked_block.update_ports_position
        puts "Bloc #{clicked_block.id} mis à jour avec #{clicked_block.input_ports.size} entrées, #{clicked_block.output_ports.size} sorties"
      end
      editor.destroy
    end
  end

  def button_release(widget, event)
    if event.button == 1
      if @current_block && @current_block.width.abs >= 20 && @current_block.height.abs >= 20
        if @current_block.width < 0
          @current_block.x += @current_block.width
          @current_block.width = @current_block.width.abs
        end
        if @current_block.height < 0
          @current_block.y += @current_block.height
          @current_block.height = @current_block.height.abs
        end

        @blocks << @current_block
        @selected_block = @current_block
        @selected_block.selected = true
      end

      @current_block = nil
      @drag_start = nil
      @drag_offset = nil
      @resizing_handle = nil
      # Ne pas réinitialiser @temp_connection ici - on veut garder la connexion en cours
      queue_draw
    end
    true
  end

  def motion_notify(widget, event)
    return true unless @drag_start || @temp_connection
    return true if @double_click_in_progress

    if @temp_connection
      # Mettre à jour la position de la connexion temporaire
      @temp_connection[:target] = { x: event.x, y: event.y }
      queue_draw
      return true
    end

    dx = event.x - @drag_start[:x]
    dy = event.y - @drag_start[:y]

    if @resizing_handle && @selected_block
      @selected_block.resize(@resizing_handle[:type], dx, dy)
      @drag_start = { x: event.x, y: event.y }
    elsif @selected_block && @drag_offset
      @selected_block.move(dx, dy)
      @drag_start = { x: event.x, y: event.y }
    elsif @current_block
      @current_block.width = dx
      @current_block.height = dy
      @current_block.create_handles
      @current_block.update_ports_position
    end

    queue_draw
    true
  end
end

# Création de la fenêtre principale
window = Gtk::Window.new(:toplevel)
window.set_title("Éditeur de Blocs - Connexions Visuelles")
window.set_default_size(1000, 700)
window.signal_connect("destroy") { Gtk.main_quit }

# Canvas
canvas = Canvas.new

# Barre d'outils avec instructions
toolbar = Gtk::Toolbar.new
toolbar.override_background_color(:normal, Gdk::RGBA.new(0.2, 0.2, 0.2, 1.0))

instructions = Gtk::ToolItem.new
label_text = <<~TEXT
  Connexions: Clic port sortie (🔴) → Déplacer → Clic port entrée (🟢) | Ligne pointillée = temporaire
  Clic-drag: créer bloc | Drag: déplacer | Poignées: redimensionner | Double-clic bloc: éditer
TEXT
label = Gtk::Label.new(label_text)
label.override_color(:normal, Gdk::RGBA.new(0.9, 0.9, 0.9, 1.0))
instructions.add(label)
toolbar.add(instructions)

vbox = Gtk::Box.new(:vertical, 0)
vbox.pack_start(toolbar, expand: false, fill: false, padding: 0)
vbox.pack_start(canvas, expand: true, fill: true, padding: 0)

window.add(vbox)
window.override_background_color(:normal, Gdk::RGBA.new(0.1, 0.1, 0.1, 1.0))

window.show_all
Gtk.main
